{
  lib,
  coreutils,
  writeShellApplication,
  symlinkJoin,
  settingsRoot,
  nixPath ? lib.strings.makeBinPath [
    "$HOME/.nix-profile"
    "\${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile"
    "/run/current-system/sw"
    "/nix/var/nix/profiles/default"
  ],
}:
let
  q = lib.escapeShellArg;
  env = name: ''(builtins.getEnv "DARWIN_SETTINGS_${name}")'';
  optional = name: ''(let value = ${env name}; in if value == "" then null else value)'';
  selection = ''
    only = ${env "ONLY"};
    scope = ${optional "SCOPE"};
  '';
  collect = ''
    f: f {
        ${selection}
        snapshots = ${optional "SNAPSHOTS"};
        capture = if ${env "CAPTURE"} == "" then null else {
          option = ${env "CAPTURE"};
          directory = ${env "DIRECTORY"};
        };
      }'';
  current = ''
    f: f {
        ${selection}
        all = ${env "ALL"} == "true";
        build = ${env "BUILD"};
        againstFile = ${optional "AGAINST"};
        against = if ${env "AGAINST"} == "" then null else
          import (builtins.toPath ${env "AGAINST"});
        collected = builtins.fromJSON (builtins.readFile (${env "WORK"} + "/state.json"));
        uiRead = false;
      }'';
  capturedPath = ''
    let
      directory = ${env "DIRECTORY"};
      cwd = ${env "CWD"};
      lib = (builtins.getFlake ("path:" + ${env "ROOT"})).inputs.nixpkgs.lib;
      relative = lib.hasPrefix (cwd + "/") directory;
      base = if relative then "./." else "/.";
      suffix = if relative then lib.removePrefix cwd directory else directory;
    in "system.settings." + ${env "CAPTURE"} + " = " + base + " + "
      + lib.generators.toPretty {} suffix + ";"
  '';
  applyActions = {
    set = {
      arguments = [
        "<option path>"
        "<nix value>"
      ];
      text = ''
        DARWIN_SETTINGS_OPTION=''${args[1]}
        # Only the explicitly supplied Nix value is evaluated as code
        expression=${q ''
          f: f (let
                      lib = (builtins.getFlake ("path:" + ${env "ROOT"})).inputs.nixpkgs.lib;
                    in lib.setAttrByPath (lib.splitString "." ${env "OPTION"}) (''}"''${args[2]}"'))'
      '';
    };
    config = {
      arguments = [ "<file.nix>" ];
      text = ''
        DARWIN_SETTINGS_CONFIG=$(realpath "''${args[1]}")
        expression=${q "f: f (import (builtins.toPath ${env "CONFIG"}))"}
      '';
    };
  };
  commands = {
    current = {
      synopsis = [ "[<file.nix>]" ];
      description = "Print this Mac's settings as system.settings values, or write them to a file";
      options = {
        scope = {
          argument = "user|system";
          choices = [
            ""
            "user"
            "system"
          ];
          description = "read settings in this scope";
        };
        against = {
          argument = "<file.nix>";
          path = true;
          description = "report differences from this configuration";
        };
        all.description = "include defaults";
        only = {
          argument = "<prefix>";
          description = "read option paths starting with this prefix";
        };
        snapshots = {
          argument = "<dir>";
          path = true;
          directory = true;
          description = "save snapshot plists in this directory";
        };
        verbose = {
          variable = "verbose";
          export = false;
          description = "list unread settings";
        };
      };
      positional = ''
        [ -z "$file" ] || usage
        file="$1"
      '';
      rejectUnknown = true;
    };
    capture = {
      synopsis = [ "<option> <directory>" ];
      options = { };
    };
    apply = {
      synopsis = lib.mapAttrsToList (
        name: action: lib.concatStringsSep " " ([ name ] ++ action.arguments)
      ) applyActions;
      options.dry-run = {
        variable = "dry_run";
        export = false;
        description = "print the activation script without applying it";
      };
      # Nix values may start with a dash, so retain unrecognized arguments
      positional = ''args+=("$1")'';
    };
  };
  variable =
    name: option:
    option.variable or "DARWIN_SETTINGS_${lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name)}";
  optionLabel =
    name: option: "--${name}" + lib.optionalString (option ? argument) " ${option.argument}";
  help = lib.mapAttrs (
    name: command:
    lib.concatMapStringsSep "\n" (
      synopsis:
      "darwin-settings-${name} ${synopsis}"
      + lib.concatMapStrings (optionName: " [${optionLabel optionName command.options.${optionName}}]") (
        lib.attrNames command.options
      )
    ) command.synopsis
    + lib.optionalString (command ? description) "\n${command.description}"
    + lib.concatMapAttrsStringSep "" (
      optionName: option: "\n  ${optionLabel optionName option}   ${option.description}"
    ) command.options
  ) commands;
  # Generate defaults, argument consumption, and validation from the same plan
  parse =
    name:
    let
      command = commands.${name};
    in
    ''
      ${lib.concatMapAttrsStringSep "\n" (
        name: option:
        lib.optionalString (option.export or true) "export "
        + lib.toShellVar (variable name option) (if option ? argument then "" else "false")
      ) command.options}
      while [ $# -gt 0 ]; do
        case "$1" in
          ${lib.concatMapAttrsStringSep "\n" (name: option: ''
            --${name})
              ${
                if option ? argument then
                  ''
                    [ $# -ge 2 ] || usage
                    ${lib.optionalString (option.directory or false) ''mkdir -p "$2"''}
                    ${variable name option}=${if option.path or false then ''$(realpath "$2")'' else ''"$2"''}
                    shift
                  ''
                else
                  ''
                    ${variable name option}=true
                  ''
              }
              ;;
          '') command.options}
          -h | --help) usage ;;
          ${lib.optionalString (command.rejectUnknown or false) "-*) usage ;;"}
          *) ${command.positional} ;;
        esac
        shift
      done
      ${lib.concatMapAttrsStringSep "\n" (
        name: option:
        lib.optionalString (option ? choices) ''
          case "${"$"}${variable name option}" in
            ${lib.concatMapStringsSep " | " q option.choices}) ;;
            *) usage ;;
          esac
        ''
      ) command.options}
    '';
  collectScript = ''
    export DARWIN_SETTINGS_WORK="$work"
    export DARWIN_SETTINGS_ONLY="" DARWIN_SETTINGS_SCOPE="" DARWIN_SETTINGS_SNAPSHOTS=""
    export DARWIN_SETTINGS_CAPTURE="" DARWIN_SETTINGS_DIRECTORY=""
    collect() {
      build_script collect ${q collect}
    }
  '';
  captureScript = ''
    [ $# -eq 2 ] || usage
    mkdir -p "$2"
    export DARWIN_SETTINGS_CAPTURE="$1" DARWIN_SETTINGS_DIRECTORY
    DARWIN_SETTINGS_DIRECTORY=$(realpath "$2")
    script=$(collect)
    /bin/bash "$script" >/dev/null
    export DARWIN_SETTINGS_CWD="$PWD"
    "''${nix_command[@]}" eval --impure --raw --expr ${q capturedPath}
    printf '\n'
    exit
  '';
  currentScript = collectScript + ''
    field() { /usr/bin/plutil -extract "$1" raw -expect string -o - "$work/result.json" 2>/dev/null; }
    # Preserve the current command's capture shorthand
    if [ "''${1:-}" = capture ]; then
      shift
      ${captureScript}
    fi

    file=""
    ${parse "current"}

    script=$(collect)
    /bin/bash "$script" >"$work/state.json"
    export DARWIN_SETTINGS_BUILD
    DARWIN_SETTINGS_BUILD=$(sw_vers -buildVersion)
    "''${nix_command[@]}" eval --impure "path:$DARWIN_SETTINGS_ROOT#lib.darwin.settings.current" --apply ${q current} --json >"$work/result.json"

    if [ -n "$file" ]; then
      field text >"$file"
      echo "wrote $file: $(field summary)" >&2
    else
      field text
      field summary >&2
    fi
    if $verbose; then
      field nothingStored >&2
    fi
  '';
  tool =
    name: script:
    writeShellApplication {
      name = "darwin-settings-${name}";
      runtimeInputs = lib.attrsets.attrValues { inherit coreutils; };
      excludeShellChecks = [ "SC2016" ];
      text = ''
        export DARWIN_SETTINGS_ROOT=${q (toString settingsRoot)}
        usage() {
          printf '%s\n' ${q help.${name}} >&2
          exit 2
        }
        ${lib.darwin.shell.nixEnvironment nixPath}
        work=$(mktemp --directory --tmpdir darwin-settings.XXXXXXXXXX)
        trap 'rm --recursive --force -- "$work"' EXIT
        build_script() {
          local function=$1 expression=$2
          # Root the script's entire string context, including generated data
          # Command substitutions do not inherit Bash's errexit by default
          "''${nix_command[@]}" build --impure --out-link "$work/script" --expr ${q ''
            let
              flake = builtins.getFlake ("path:" + ${env "ROOT"});
              pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
            in pkgs.writeText "darwin-settings-script" (
          ''}"($expression) flake.lib.darwin.settings.$function)" || return
          # Execute the rooted file without passing its contents through argv
          printf '%s\n' "$work/script"
        }
        ${script}
      '';
    };
in
symlinkJoin {
  name = "darwin-settings";
  paths = [
    (tool "current" currentScript)
    (tool "capture" (collectScript + captureScript))
    (tool "apply" ''
      args=()
      ${parse "apply"}

      export DARWIN_SETTINGS_OPTION="" DARWIN_SETTINGS_CONFIG=""
      case "''${args[0]:-}" in
        ${lib.concatMapAttrsStringSep "\n" (name: action: ''
          ${name})
            [ "''${#args[@]}" -eq ${toString (1 + lib.length action.arguments)} ] || usage
            ${action.text}
            ;;
        '') applyActions}
        *) usage ;;
      esac

      if $dry_run; then
        script=$("''${nix_command[@]}" eval --raw --impure "path:$DARWIN_SETTINGS_ROOT#lib.darwin.settings.applyScript" --apply "$expression")
        printf '%s\n' "$script"
      else
        script=$(build_script applyScript "$expression")
        /bin/bash -eu "$script"
      fi
    '')
  ];
}

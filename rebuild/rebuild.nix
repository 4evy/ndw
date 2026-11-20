{
  lib,
  pkgs,
  profile ? "/nix/var/nix/profiles/system",
  nixPath ? lib.strings.makeBinPath [
    "$HOME/.nix-profile"
    "\${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile"
    "/run/current-system/sw"
    "/nix/var/nix/profiles/default"
  ],
}:
let
  inherit (lib.darwin.shell) fail failIf;
  activationPaths = import ../modules/system/activation/paths.nix;
  activate = rollback: ''
    # Legacy scripts cannot participate in the lock and success journal
    ${failIf ''! /usr/bin/grep -Fqx '# darwin: profile-aware activation' "$system/activate"'' "this system cannot commit an ndw activation, rebuild its configuration with the current core"}
    "''${as_root[@]}" "$system/activate" --profile "$profile" ${lib.strings.optionalString rollback ''--generation "$generation"''}
  '';
  actions = {
    build = {
      build = true;
      rooted = false;
      flags = [ ];
      text = ''printf '%s\n' "$system"'';
    };
    switch = {
      build = true;
      rooted = true;
      flags = [ ];
      text = ''
        if [[ -n $profile_name && $profile_name != system && ! -d $system_profiles ]]; then
          "''${as_root[@]}" ${lib.meta.getExe' pkgs.coreutils "mkdir"} --parents --mode=755 -- "$system_profiles"
        fi
        ${activate false}
      '';
    };
    check = {
      build = true;
      rooted = true;
      flags = [ ];
      text = ''
        ${failIf ''! /usr/bin/grep -Fqx '# darwin: check-aware activation' "$system/activate"'' "this system does not advertise read-only activation checks, rebuild it with the current core"}
        "''${as_root[@]}" "$system/activate" --check
      '';
    };
    activate = {
      build = false;
      nix = false;
      text = ''
        ${failIf "[[ $0 != */sw/bin/darwin && $0 != */sw/bin/darwin-rebuild ]]" "run activate through a built system at sw/bin/darwin or sw/bin/darwin-rebuild"}
        system=$(readlink --canonicalize -- "''${0%/sw/bin/*}")
        ${failIf "[[ ! -x $system/activate ]]" "run activate through a built system at sw/bin/darwin or sw/bin/darwin-rebuild"}
        exec "''${as_root[@]}" "$system/activate"
      '';
    };
    repair = {
      build = false;
      nix = false;
      text = ''
        activation_state=${lib.strings.escapeShellArg activationPaths.state}
        ${builtins.readFile ../modules/system/activation/recovery.sh}
        system=$(activation_recovery_system "$profile")
        ${failIf ''[[ ! -x $system/activate ]] || ! /usr/bin/grep -Fqx '# darwin: boot-aware activation' "$system/activate"'' "repair requires a successful generation built with boot-aware activation"}
        exec "''${as_root[@]}" "$system/activate" --boot
      '';
    };
    generations = {
      build = false;
      text = ''
        if [[ -n $profile_name && $profile_name != system && ! -e $system_profiles ]]; then exit 0; fi
        exec nix-env --profile "$profile" --list-generations
      '';
    };
    rollback = {
      build = false;
      text = ''
        if [[ -z $generation ]]; then
          generations=$(nix-env --profile "$profile" --list-generations)
          current_found=false
          while read -r candidate _date _time marker; do
            if [[ $marker == '(current)' ]]; then
              current_found=true
              break
            fi
            generation=$candidate
          done <<< "$generations"
          ${failIf "[[ $current_found == false ]]" "cannot identify the current generation, select one with --generation N"}
        fi
        ${failIf "[[ ! $generation =~ ^[0-9]+$ ]]" "no previous generation, select one with --generation N"}
        system=$(readlink --canonicalize -- "$profile-$generation-link")
        if [[ ! -x $system/activate ]]; then
          printf >&2 'error: generation %s is not a built Darwin system\n' "$generation"
          exit 2
        fi
        ${activate true}
      '';
    };
  };
  names = predicate: builtins.attrNames (lib.attrsets.filterAttrs (_: predicate) actions);
  buildActions = names (action: action.build);
  options = {
    flake = {
      variable = "flake";
      default = "";
      argument = "URI#NAME";
      description = "configuration flake and name";
      actions = buildActions;
    };
    profile = {
      variable = "profile_path";
      default = "";
      argument = "PATH";
      description = "system profile for generations and switching";
    };
    generation = {
      variable = "generation";
      default = "";
      argument = "N";
      description = "generation to select with rollback";
      actions = [ "rollback" ];
    };
    dry-run = {
      variable = "dry";
      default = "";
      description = "show a build without activating";
      actions = buildActions;
    };
  };
  command = lib.strings.escapeShellArgs;
  # Nix selects each action's validation, setup, and rooting policy
  dispatch = lib.strings.concatMapAttrsStringSep "\n" (name: action: ''
    ${name})
      ${lib.strings.concatMapAttrsStringSep "\n"
        (
          optionName: option:
          failIf "[[ -n ${"$"}${option.variable} ]]" "--${optionName} requires ${lib.strings.concatStringsSep ", " option.actions}"
        )
        (
          lib.attrsets.filterAttrs (_: option: option ? actions && !builtins.elem name option.actions) options
        )
      }
      ${lib.strings.optionalString (!action.build) (
        failIf "[[ \${#flags[@]} -gt 0 ]]" "forwarded Nix build flags require build, check, or switch"
      )}
      ${lib.strings.optionalString (action.nix or true) "setup_nix"}
      ${lib.strings.optionalString action.build ''
        prepare_build
        ${lib.strings.optionalString action.rooted ''
          if [[ -n $out_link_flag && -z $dry ]]; then
            printf >&2 'error: %s would override the temporary build root\n' "$out_link_flag"
            exit 2
          fi
        ''}
        select_configuration
        if [[ -n $dry ]]; then
          exec "''${build[@]}" --dry-run "''${flags[@]}" -- "$installable"
        fi
        ${lib.strings.optionalString action.rooted ''
          # Keep the build rooted through checks and activation, including
          # failures before the activation journal takes ownership
          build_root=$(mktemp --directory --tmpdir darwin-build.XXXXXXXXXX)
          trap 'rm --recursive --force -- "$build_root"' EXIT
        ''}
        # Internal rooting must win even over clustered Nix short options
        system=$("''${build[@]}" --print-out-paths ${command action.flags} "''${flags[@]}" ${lib.strings.optionalString action.rooted ''--out-link "$build_root/system"''} -- "$installable")
        ${failIf ''[[ -z $system || $system == *$'\n'* || ! -x $system/activate ]]'' "expected one built Darwin system, check the forwarded Nix build flags"}
          ${lib.strings.optionalString action.rooted ''
            ${failIf ''[[ ! -L $build_root/system || $(readlink --canonicalize-existing -- "$build_root/system") != "$system" ]]'' "Nix did not create the required local build root, use the local store for activation"}
          ''}
      ''}
      ${action.text}
      ;;
  '') actions;
  parse = lib.strings.concatMapAttrsStringSep "\n" (name: option: ''
    --${name})
      ${
        if option ? argument then
          ''
            if [[ $# -lt 2 || -z $2 ]]; then
              printf >&2 'error: %s needs a value\n' "$1"
              exit 2
            fi
            ${option.variable}=$2
            shift 2
          ''
        else
          ''
            ${option.variable}=1
            shift
          ''
      }
      ;;
  '') options;
  # Classify Nix options before looking at their literal arguments, including
  # values that look like rebuild flags. Only evaluation options reach lookup
  nixOptions = [
    {
      patterns = [
        "--arg"
        "--argstr"
        "--arg-from-file"
        "--option"
        "--override-input"
        "--override-flake"
      ];
      arguments = 2;
      forward = true;
    }
    {
      patterns = [ "--arg-from-stdin" ];
      arguments = 1;
      forward = false;
    }
    {
      patterns = [
        "--eval-store"
        "--store"
        "--include"
        "-I"
        "--inputs-from"
        "--update-input"
        "--reference-lock-file"
        "--output-lock-file"
      ];
      arguments = 1;
      forward = true;
    }
    {
      patterns = [
        "--impure"
        "--offline"
        "--refresh"
        "--no-registries"
        "--no-use-registries"
        "--no-update-lock-file"
        "--no-write-lock-file"
        "--recreate-lock-file"
        "--commit-lock-file"
        "--accept-flake-config"
        "--no-accept-flake-config"
        "--show-trace"
        "--eval-store=*"
        "--store=*"
        "-I?*"
      ];
      arguments = 0;
      forward = true;
    }
    {
      patterns = [
        "--cores"
        "--max-jobs"
        "-j"
        "--log-format"
        "--substituters"
      ];
      arguments = 1;
      forward = false;
    }
    {
      patterns = [
        "--verbose"
        "-v"
        "-vv"
        "-vvv"
        "-vvvv"
        "-vvvvv"
        "--print-build-logs"
        "-L"
        "-vL"
        "-j[0-9]*"
        "--keep-going"
        "--keep-failed"
        "--fallback"
      ];
      arguments = 0;
      forward = false;
    }
  ];
  parseEvaluationOptions = lib.strings.concatMapStringsSep "\n" (option: ''
    ${lib.strings.concatStringsSep "|" option.patterns})
      ${lib.strings.optionalString option.forward ''eval_flags+=("$flag")''}
      ${lib.strings.optionalString (option.arguments > 0) ''
        eval_flag=${lib.trivial.boolToString option.forward}
        remaining=${toString option.arguments}
      ''}
      ;;
  '') (lib.lists.filter (option: option.forward || option.arguments > 0) nixOptions);
  parseNixOptions = lib.strings.concatMapStringsSep "\n" (option: ''
    ${lib.strings.concatStringsSep "|" option.patterns})
      ${lib.strings.optionalString (option.arguments > 0) (
        failIf "[[ $# -le ${toString option.arguments} ]]" "forwarded Nix option is missing required arguments"
      )}
      flags+=("''${@:1:${toString (option.arguments + 1)}}")
      shift ${toString (option.arguments + 1)}
      ;;
  '') nixOptions;
  usage = "{${lib.strings.concatStringsSep "|" (builtins.attrNames actions)}} [options] [-- nix build flags]";
  help = [
    "  --list-generations                   alias for generations"
    "  [switch] --rollback                 alias for rollback"
    "  [switch] --switch-generation N      alias for rollback --generation N (short: -G N)"
    "  --profile-name NAME                 named profile for generations, rollback, or switch (short: -p NAME)"
    "  use -- to pass additional Nix build flags"
    "  builds run as the caller, activation uses sudo when needed"
    "  repair restores core files and links from the last successful system without building"
  ]
  ++ lib.attrsets.mapAttrsToList (
    name: option:
    "  --${name}${
        lib.strings.optionalString (option ? argument) " ${option.argument}"
      }   ${option.description}"
  ) options;
in
pkgs.writeShellApplication {
  name = "darwin";
  derivationArgs.postCheck = ''
    ln -s darwin "$out/bin/darwin-rebuild"
  '';
  runtimeInputs = lib.attrsets.attrValues { inherit (pkgs) coreutils; };
  text = ''
    ${lib.strings.toShellVars (
      (lib.attrsets.mapAttrs' (
        _: option: lib.attrsets.nameValuePair option.variable option.default
      ) options)
      // {
        inherit profile;
        flags = [ ];
        as_root = [ ];
        profile_name = "";
        action = "";
        legacy_action = "";
      }
    )}
    usage() {
      printf '%s %s\n' "''${0##*/}" ${lib.strings.escapeShellArg usage}
      ${command (
        [
          "printf"
          "%s\n"
        ]
        ++ help
      )}
    }
    if [[ $# == 0 || ''${1:-} == --help ]]; then
      usage
      exit 0
    fi
    system_profiles=/nix/var/nix/profiles/system-profiles
    while [[ $# -gt 0 ]]; do
      case $1 in
      ${parse}
      ${lib.strings.concatStringsSep "|" (builtins.attrNames actions)})
        ${failIf "[[ -n $action ]]" "specify only one action"}
        action=$1
        shift
        ;;
      --list-generations|--rollback|--switch-generation|-G)
        ${failIf "[[ -n $legacy_action ]]" "specify only one generation action"}
        case $1 in
        --list-generations) legacy_action=generations ;;
        --rollback) legacy_action=rollback ;;
        *)
          ${failIf "[[ $# -lt 2 || ! $2 =~ ^[0-9]+$ ]]" "select a generation number with --switch-generation N"}
          legacy_action=rollback
          generation=$2
          shift
          ;;
        esac
        shift
        ;;
      --profile-name|-p)
        ${failIf "[[ $# -lt 2 || -z $2 || $2 == -* || $2 == . || $2 == .. || $2 == */* ]]" "profile name must be a single nonempty path component not starting with a dash"}
        ${failIf "[[ $2 =~ -[0-9]+-link ]]" "profile name must not be mistaken for a generation link"}
        profile_name=$2
        shift 2
        ;;
      --no-flake)
        ${fail "error: --no-flake is not supported, select a configuration with --flake URI#NAME"}
        ;;
      edit|changelog)
        printf >&2 'error: action %s is not supported\n' "$1"
        exit 2
        ;;
      -k|-K)
        if [[ $1 == -k ]]; then flags+=(--keep-going); else flags+=(--keep-failed); fi
        shift
        ;;
      ${parseNixOptions}
      --help)
        usage
        exit 0
        ;;
      --)
        shift
        flags+=("$@")
        break
        ;;
      *)
        printf >&2 'error: unknown option %s\n' "$1"
        exit 2
        ;;
      esac
    done
    if [[ -n $legacy_action ]]; then
      case "$action:$legacy_action" in
      :*|generations:generations|rollback:rollback|switch:rollback) action=$legacy_action ;;
      *) ${fail "error: generation action conflicts with the requested action"} ;;
      esac
    fi
    ${failIf "[[ -n $profile_path && -n $profile_name ]]" "choose either --profile PATH or --profile-name NAME"}
    if [[ -n $profile_name ]]; then
      case $action in
      generations|rollback|switch) ;;
      *) ${fail "error: --profile-name requires generations, rollback, or switch"} ;;
      esac
      if [[ $profile_name != system ]]; then
        ${failIf "[[ -L $system_profiles ]]" "system-profiles must not be a symlink"}
        profile=$system_profiles/$profile_name
      fi
    elif [[ -n $profile_path ]]; then
      profile=$profile_path
    fi
    # Build with the caller's credentials, then elevate only activation
    if [[ $(id --user) == 0 ]]; then
      export HOME=~root
    else
      as_root=(/usr/bin/sudo --set-home --user=root --)
    fi
    setup_nix() {
      ${lib.darwin.shell.nixEnvironment nixPath}
    }
    prepare_build() {
      build=("''${nix_command[@]}" build)
      if [[ -z $flake ]]; then
        if [[ -e /etc/nix-darwin/flake.nix ]]; then
          flake=$(dirname -- "$(readlink --canonicalize -- /etc/nix-darwin/flake.nix)")
        else
          flake=.
        fi
      fi
      if [[ $flake == *'#'* ]]; then
        name=''${flake##*#}
        flake=''${flake%#*}
      else
        if ! name=$(/usr/sbin/scutil --get LocalHostName); then
          printf >&2 'error: cannot read LocalHostName, select a configuration with --flake URI#NAME\n'
          exit 2
        fi
      fi
      ${failIf "[[ -z $name ]]" "configuration name is empty"}
      # Nix's attribute selection syntax has no escape for an embedded quote
      ${failIf ''[[ $name == *\"* ]]'' "configuration names must not contain double quotes"}
      # Nix build can change profiles itself, before activation has succeeded
      remaining=0
      out_link_flag=
      eval_flags=()
      eval_flag=false
      for flag in "''${flags[@]}"; do
        if (( remaining > 0 )); then
          if [[ $eval_flag == true ]]; then eval_flags+=("$flag"); fi
          remaining=$((remaining - 1))
          continue
        fi
        case $flag in
        ${parseEvaluationOptions}
        --profile|--profile=*)
          printf >&2 'error: %s bypasses activation, use darwin switch --profile PATH\n' "$flag"
          exit 2
          ;;
        --no-link|--out-link|--out-link=*|-o|-o?*)
          out_link_flag=$flag
          ;;
        esac
      done
      ${failIf "[[ $remaining != 0 ]]" "forwarded Nix option is missing required arguments"}
    }
    select_configuration() {
      # Accept nix-darwin's darwinConfigurations as a compatibility alias,
      # preferring darwin.configurations when both output sets are present
      configurations=$("''${nix_command[@]}" eval "''${eval_flags[@]}" --raw --apply '
        flake: if flake ? darwin.configurations
        then "darwin.configurations" else "darwinConfigurations"
      ' -- "$flake#.")
      installable="$flake#$configurations.\"$name\".system"
    }
    case $action in
    ${dispatch}
    *)
      usage >&2
      exit 2
      ;;
    esac
  '';
  excludeShellChecks = [ "SC2016" ];
}

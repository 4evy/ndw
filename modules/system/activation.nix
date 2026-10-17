{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.system.activation;
  entries = lib.attrsets.mapAttrsToList (name: step: step // { inherit name; }) cfg.steps;
  missing = lib.lists.concatMap (
    step:
    map (dependency: "${step.name} -> ${dependency}") (
      lib.lists.filter (dependency: !builtins.hasAttr dependency cfg.steps) step.deps
    )
  ) entries;
  self = map (step: step.name) (lib.lists.filter (step: builtins.elem step.name step.deps) entries);
  sorted = lib.lists.toposort (a: b: builtins.elem a.name b.deps) entries;
  ordered =
    if missing != [ ] then
      throw "Unknown activation dependencies: ${lib.strings.concatStringsSep ", " missing}"
    else if self != [ ] then
      throw "Activation steps depend on themselves: ${lib.strings.concatStringsSep ", " self}"
    else if sorted ? result then
      sorted.result
    else
      throw "Activation dependency cycle: ${
        lib.strings.concatMapStringsSep " -> " (step: step.name) sorted.cycle
      }";
  collect = field: lib.strings.concatMapStringsSep "\n" (step: step.${field}) ordered;
  bootSteps = lib.lists.filter (step: step.on.boot) ordered;
  collectBoot = field: lib.strings.concatMapStringsSep "\n" (step: step.${field}) bootSteps;
  command = lib.strings.escapeShellArgs;
  inherit (lib.darwin.shell) failIf;
  valueOptions = [
    "profile"
    "generation"
  ];
  parseOptions = lib.strings.concatMapStringsSep "\n" (name: ''
    --${name})
      ${failIf "[[ $# -lt 2 || -z $2 ]]" "--${name} needs a value"}
      ${name}=$2
      shift 2
      ;;
  '') valueOptions;
in
{
  options.system.activation = {
    runtimeInputs =
      mkDefaultOption (lib.types.listOf lib.types.package) [ ]
        "Packages available to activation functions, checks, and commands.";
    functions = mkDefaultOption lib.types.lines "" "Shell functions used by checks and activation.";
    checks = mkDefaultOption lib.types.lines "" "Read-only checks run before activation.";
    content =
      mkDefaultOption lib.types.lines ""
        "Custom activation commands run after the core steps. Fragments can use lib.modules.mkOrder.";
    steps =
      mkDefaultOption
        (lib.types.attrsOf (
          lib.types.submodule {
            options = {
              on.boot = mkDefaultOption lib.types.bool false ''
                Run this step when restoring the successful system at boot.
                Its dependencies must also run at boot. Boot restoration does
                not commit a generation or clear failed activation attempts.
              '';
              runtimeInputs =
                mkDefaultOption (lib.types.listOf lib.types.package) [ ]
                  "Packages required by this step's functions, checks, and commands.";
              deps = mkDefaultOption (lib.types.listOf lib.types.str) [ ] "Steps that must run before this step.";
              functions = mkDefaultOption lib.types.lines "" "Shell functions used by this step.";
              checks = mkDefaultOption lib.types.lines "" "Read-only checks run before activation.";
              prepare = mkDefaultOption lib.types.lines "" ''
                Permission probes run after read-only checks and before any
                activation commands. Skipped by --check and boot restoration.
                Probes run in a subshell and must preserve existing system
                configuration.
              '';
              text = mkDefaultOption lib.types.lines "" "Commands that realize this activation step.";
            };
          }
        ))
        { }
        ''
          Named activation steps ordered by dependencies. All functions and
          read-only checks run before any step's activation commands.
          Permission probes run between read-only checks and activation.
          Custom steps can depend on run, files, launchd, or extra.
        '';
  };
  config = {
    assertions = map (step: {
      assertion = lib.lists.all (dependency: cfg.steps.${dependency}.on.boot) step.deps;
      message = "Boot activation step ${step.name} depends on a step that does not run at boot";
    }) bootSteps;
    system.activation.steps = {
      extra = {
        deps = [ "launchd" ];
        inherit (cfg) functions checks;
        text = cfg.content;
      };
      run = {
        on.boot = true;
        checks = ''
          macos_version=$(/usr/bin/sw_vers -productVersion)
          ${failIf ''[[ ! $macos_version =~ ^[0-9]+(\.[0-9]+)*$ ]] || (( ''${macos_version%%.*} < 27 ))'' "activation requires macOS 27 or newer"}
          ${failIf "[[ $(/usr/sbin/sysctl -n hw.optional.arm64) != 1 ]]" "activation requires Apple Silicon"}
          ${failIf "[[ ( -e /etc/synthetic.conf || -L /etc/synthetic.conf ) && ! -f /etc/synthetic.conf ]]" "/etc/synthetic.conf must be a regular file"}
          ${failIf "[[ ( -e /run || -L /run ) && ( ! -L /run || $(readlink --canonicalize -- /run) != /private/var/run ) ]]" "existing /run must resolve to /private/var/run"}
          run_configured=false
          for manifest in /etc/synthetic.conf /etc/synthetic.d/*; do
            if [[ ! -f $manifest ]]; then continue; fi
            while IFS= read -r line || [[ -n $line ]]; do
              case $line in
              run|run[$'\t ']* )
                run_target=''${line#*$'\t'}
                if [[ $run_configured == true || $line != run$'\t'* || "/''${run_target#/}/" == /run/* || $(readlink --canonicalize -- "/''${run_target#/}") != /private/var/run ]]; then
                  printf >&2 'error: conflicting or duplicate run entry in %s\n' "$manifest"
                  exit 2
                fi
                run_configured=true
                ;;
              esac
            done < "$manifest"
          done
          if [[ $run_configured == false ]]; then
            ${failIf "[[ ( -e /etc/synthetic.d || -L /etc/synthetic.d ) && ( ! -d /etc/synthetic.d || -L /etc/synthetic.d ) ]]" "/etc/synthetic.d must be a directory, not a symlink"}
            ${failIf "[[ -e /etc/synthetic.d/darwin.conf || -L /etc/synthetic.d/darwin.conf ]]" "refusing to overwrite an unrelated /etc/synthetic.d/darwin.conf"}
          fi
        ''
        + lib.strings.optionalString (config.system.primary.user != null) (
          command [
            "id"
            "--"
            config.system.primary.user
          ]
          + " >/dev/null"
        );
        text = ''
          if [[ $run_configured == false ]]; then
            mkdir --parents -- /etc/synthetic.d
            install --mode=644 --no-target-directory -- ${pkgs.writeText "darwin-synthetic.conf" "run\tprivate/var/run\n"} /etc/synthetic.d/darwin.conf
          fi
          ${failIf "[[ ! -L /run ]] && ! /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t" "could not synthesize /run, a reboot may be required"}
          ${failIf "[[ ! -L /run || $(readlink --canonicalize -- /run) != /private/var/run ]]" "/run must resolve to /private/var/run"}
        '';
      };
    };
    system.build.activation =
      (pkgs.writeShellApplication {
        name = "activate";
        runtimeInputs = lib.lists.unique (
          lib.attrsets.attrValues { inherit (pkgs) coreutils flock; }
          ++ cfg.runtimeInputs
          ++ lib.lists.concatMap (step: step.runtimeInputs) ordered
        );
        runtimeEnv = {
          PATH = "/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          USER = "root";
          LOGNAME = "root";
          HOME = "/var/root";
          MAIL = "/var/mail/root";
          SHELL = lib.meta.getExe pkgs.bash;
          LANG = "C";
          LC_CTYPE = "UTF-8";
          NIX_REMOTE = "daemon";
        };
        excludeShellChecks = [
          "SC2016"
          "SC1112"
        ];
        text = ''
          # darwin: profile-aware activation
          # darwin: boot-aware activation
          # darwin: check-aware activation
          # Resolve the containing system, preserving the activate symlink
          # itself
          system=$(readlink --canonicalize -- "$(dirname -- "$0")")
          ${failIf "[[ ! -f $system/files.json || ! -d $system/launchd ]]" "run activate through a built system"}
          umask 0022
          ${failIf "[[ $(id --user) != 0 ]]" "activation requires root"}
          ${lib.strings.toShellVars (
            lib.attrsets.genAttrs valueOptions (_: "")
            // {
              check = "false";
              boot = "false";
            }
          )}
          while [[ $# -gt 0 ]]; do
            case $1 in
            --check) check=true; shift ;;
            --boot) boot=true; shift ;;
            ${parseOptions}
            *) printf >&2 'usage: activate [--check] [--profile PATH [--generation N]]\n'; exit 2 ;;
            esac
          done
          ${failIf "[[ -n $generation && ( -z $profile || ! $generation =~ ^[0-9]+$ ) ]]" "--generation requires --profile and a generation number"}
          ${failIf "[[ $boot == true && ( $check == true || -n $profile || -n $generation ) ]]" "--boot cannot be combined with check or profile options"}
          # Find an existing Nix installation without adding the entire system
          # environment to the activation PATH
          if ! command -v nix-env >/dev/null \
            && nix_env=$(PATH=${lib.darwin.shell.doubleQuote (lib.strings.makeBinPath config.environment.profiles)} command -v nix-env); then
            nix_env=$(readlink --canonicalize -- "$nix_env")
            PATH="$PATH:$(dirname -- "$nix_env")"
            export PATH
          fi
          if [[ -n $profile ]]; then
            ${failIf "! command -v nix-env >/dev/null" "profile updates require nix-env in the activation PATH"}
            # Canonicalize the directory without following the profile symlink
            profile="$(readlink --canonicalize-missing -- "$(dirname -- "$profile")")/$(basename -- "$profile")"
            ${failIf ''[[ -n $generation && $(readlink --canonicalize -- "$profile-$generation-link") != "$system" ]]'' "rollback generation does not select this system"}
          fi
          cd /
          activation_state=/nix/var/nix/gcroots/darwin
          # This lock coordinates this activator, not direct nix-env calls or
          # external edits to the managed filesystem
          if [[ $check == false ]]; then
            install --directory --mode=755 -- "$activation_state/pending"
            exec 9>/nix/var/nix/darwin-activation.lock
            ${failIf "! flock --exclusive --nonblock 9" "another Darwin activation is in progress"}
          elif [[ -f /nix/var/nix/darwin-activation.lock ]]; then
            exec 9</nix/var/nix/darwin-activation.lock
            ${failIf "! flock --shared --nonblock 9" "another Darwin activation is in progress"}
          fi
          if [[ $boot == true ]]; then
            selected="$activation_state/current"
            if [[ ! -e $selected ]]; then selected=${lib.strings.escapeShellArg config.system.profile}; fi
            ${failIf ''[[ $(readlink --canonicalize -- "$selected") != "$system" ]]'' "boot restoration must select the last successful system"}
          fi
          if [[ $check == false ]]; then
            # Checks may execute store programs before this attempt is journaled
            # Keep that root separate from attempts that passed preflight
            ln --symbolic --force --no-target-directory -- "$system" "$activation_state/incoming"
            trap 'rm --force -- "$activation_state/incoming"' EXIT
          fi
          # Failed attempts stay rooted until a successful activation reconciles
          # their files, jobs, and environment with the requested generation
          # This journal does not undo arbitrary hooks or roll back live changes
          # automatically. An interrupted attempt can leave mixed live state
          # until a retry or rollback reconciles it
          # TODO: Verify power-loss durability on a disposable APFS system
          activation_previous_systems=()
          for previous in "$activation_state/current" /run/current-system "$activation_state"/pending/*; do
            if [[ ! -d $previous ]]; then continue; fi
            previous=$(readlink --canonicalize -- "$previous")
            if [[ " ''${activation_previous_systems[*]} " != *" $previous "* ]]; then
              activation_previous_systems+=("$previous")
            fi
          done
          if [[ $boot == true ]]; then
            ${collectBoot "functions"}
            ${collectBoot "checks"}
          else
            ${collect "functions"}
            ${collect "checks"}
          fi
          if [[ $check == true ]]; then
            printf 'Activation checks passed\n'
            exit 0
          fi
          if [[ $boot == false ]]; then
            (
              trap - EXIT
              :
              ${collect "prepare"}
            ) 9>&-
          fi
          if [[ $boot == false && ! -e $activation_state/current && -d /run/current-system ]]; then
            activation_live_system=$(readlink --canonicalize-existing -- /run/current-system)
            activation_live_pending="$activation_state/pending/''${activation_live_system##*/}"
            # A first activation can publish runtime links before its commit
            # Adopt only live systems that are outside the failure journal
            if [[ ! -e $activation_live_pending && ! -L $activation_live_pending ]]; then
              ln --symbolic --no-target-directory -- "$activation_live_system" "$activation_state/current"
            fi
          fi
          if [[ $boot == false ]]; then
            pending="$activation_state/pending/''${system##*/}"
            if [[ ! -L $pending ]]; then
              ln --symbolic --no-target-directory -- "$system" "$pending"
            fi
            ${failIf ''[[ $(readlink --canonicalize -- "$pending") != "$system" ]]'' "activation journal contains an unexpected target"}
          fi
          rm --force -- "$activation_state/incoming"
          trap 'if [[ $? != 0 ]]; then printf >&2 "error: activation failed, retry or activate a previous generation to reconcile pending changes\n"; fi' EXIT
          # Background processes started by hooks must not inherit the lock
          (
            trap - EXIT
            if [[ $boot == true ]]; then
              ${collectBoot "text"}
            else
              ${collect "text"}
            fi
          ) 9>&-
          ln --symbolic --force --no-target-directory -- "$system" /run/current-system
          mkdir --parents -- /nix/var/nix/gcroots
          ln --symbolic --force --no-target-directory -- /run/current-system /nix/var/nix/gcroots/current-system
          if [[ -n $profile ]]; then
            if [[ -n $generation ]]; then
              ${failIf ''[[ $(readlink --canonicalize -- "$profile-$generation-link") != "$system" ]]'' "rollback generation changed during activation"}
              nix-env --profile "$profile" --switch-generation "$generation"
            else
              nix-env --profile "$profile" --set "$system"
            fi
          fi
          if [[ $boot == false ]]; then
            # Publish success only after all required system links exist
            ln --symbolic --force --no-target-directory -- "$system" "$activation_state/current.next"
            mv --force --no-target-directory -- "$activation_state/current.next" "$activation_state/current"
            rm --force -- "$activation_state"/pending/*
          fi
        '';
      }).overrideAttrs
        (previous: {
          # Clear startup variables before Bash can read BASH_ENV or SHELLOPTS
          # Invoke this executable directly. Running it through another shell
          # bypasses the shebang and that shell's startup cannot be isolated
          # here
          text =
            lib.strings.replaceStrings
              [ "#!${pkgs.runtimeShell}" ]
              [ "#!/usr/bin/env -i ${pkgs.runtimeShell}\n# shellcheck shell=bash\n# shellcheck disable=SC2096" ]
              previous.text;
        });
  };
}

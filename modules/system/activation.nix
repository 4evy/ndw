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
  bootSteps = lib.lists.filter (step: step.on.boot) ordered;
  render =
    field: phase: steps:
    lib.strings.concatMapStringsSep "\n" (step: ''
      activation_stage=${lib.strings.escapeShellArg "${phase} step ${step.name}"}
      ${step.${field}}
    '') (lib.lists.filter (step: step.${field} != "") steps);
  preflight = steps: ''
    activation_stage='loading activation functions'
    ${lib.strings.concatMapStringsSep "\n" (step: step.functions) steps}
    ${render "checks" "checking" steps}
  '';
  legacyHooks = config.system.activationScripts;
  paths = import ./activation/paths.nix;
  runner =
    builtins.replaceStrings
      [ "# @boot-preflight@" "# @preflight@" "# @prepare@" "# @boot-apply@" "# @apply@" ]
      [
        (preflight bootSteps)
        (preflight ordered)
        (render "prepare" "probing" ordered)
        (render "text" "restoring" bootSteps)
        (
          lib.strings.optionalString
            (lib.lists.any (hook: hook.text != "") (lib.attrsets.attrValues legacyHooks))
            ''
              # shellcheck disable=SC2034
              systemConfig=$system
            ''
          + lib.strings.optionalString (legacyHooks.preActivation.text != "") ''
            activation_stage='running preActivation'
            ${legacyHooks.preActivation.text}
          ''
          + render "text" "applying" ordered
        )
      ]
      (builtins.readFile ./activation/activate.sh);
in
{
  imports = [
    ./activation/run.nix
    (lib.modules.mkAliasOptionModule
      [ "system" "activationScripts" "postActivation" "text" ]
      [ "system" "activation" "content" ]
    )
  ];
  options.system.activationScripts = {
    preActivation.text = mkDefaultOption lib.types.lines "" ''
      Legacy root activation hook. Runs after ndw's preflight and before
      normal activation steps, never during a check or boot restore.
    '';
    users.text = mkDefaultOption lib.types.lines "" ''
      Legacy root activation hook. Runs after account setup and before
      application installation, never during a check or boot restore.
    '';
    applications.text = mkDefaultOption lib.types.lines "" ''
      Legacy root activation hook. Runs after application installation and
      before loading launchd jobs, never during a check or boot restore.
    '';
  };
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
          Activation commands must be idempotent so a failed switch can be
          retried. Use a subshell for steps that exit early.
        '';
  };
  config = {
    assertions = map (step: {
      assertion = lib.lists.all (dependency: cfg.steps.${dependency}.on.boot) step.deps;
      message = "Boot activation step ${step.name} depends on a step that does not run at boot";
    }) bootSteps;
    system.activation.steps = {
      legacy-users = {
        deps = [ "users" ];
        inherit (legacyHooks.users) text;
      };
      applications.deps = [ "legacy-users" ];
      legacy-applications = {
        deps = [ "applications" ];
        inherit (legacyHooks.applications) text;
      };
      launchd.deps = [ "legacy-applications" ];
      extra = {
        deps = [ "launchd" ];
        inherit (cfg) functions checks;
        text = cfg.content;
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
        text =
          lib.strings.toShellVars {
            activation_default_profile = config.system.profile;
            activation_state = paths.state;
            activation_lock = paths.lock;
          }
          + "\n"
          + ''
            activation_nix_path=${lib.darwin.shell.doubleQuote (lib.strings.makeBinPath config.environment.profiles)}
          ''
          + builtins.readFile ./activation/recovery.sh
          + runner;
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

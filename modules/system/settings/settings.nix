{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin) settings;
  inherit (lib.darwin.shell) asUser;
  inherit (settings) catalog;
  cfg = config.system.settings;
  primaryUser = config.system.primary.user;
  build =
    scope:
    settings.module.build {
      tree = catalog;
      values = cfg;
      inherit scope;
      inherit (cfg) ignoreWarnings;
    };
  user = build "user";
  system = build "system";
  script =
    scope: generated:
    lib.getExe (
      pkgs.writeShellApplication {
        name = "darwin-${scope}-settings";
        text = generated.script;
        # Shortcut strings such as @$t contain literal dollar signs
        excludeShellChecks = [ "SC2016" ];
      }
    );
  owned = lib.filter (leaf: lib.attrByPath leaf.path null cfg != null) (
    settings.module.settingsIn catalog
  );
  defaultsDomains = lib.darwin.defaults.domains config.system.defaults;
  normalize =
    domain:
    if
      lib.elem domain [
        "NSGlobalDomain"
        ".GlobalPreferences"
        "-g"
      ]
    then
      "-g"
    else
      lib.removeSuffix ".plist" (lib.removePrefix "/Library/Preferences/" domain);
  explicitKeys = lib.concatLists (
    lib.mapAttrsToList (
      scope: domains:
      lib.concatLists (
        lib.mapAttrsToList (
          domain: values:
          map (name: {
            inherit name;
            scope = if scope == "userByHost" then "user" else scope;
            domain = normalize domain;
          }) (lib.attrNames (lib.filterAttrs (_: value: value != null) values))
        ) domains
      )
    ) defaultsDomains
  );
  conflictsWithDefaults =
    key:
    lib.any (
      explicit:
      explicit.scope == key.scope
      && explicit.domain == normalize key.domain
      && (key.name == null || explicit.name == key.name)
    ) explicitKeys;
  conflicts = lib.filter (leaf: lib.any conflictsWithDefaults (lib.attrValues leaf.entry.keys)) owned;
  plannedConflicts = lib.filter (step: step ? key && conflictsWithDefaults step.key) (
    user.plan ++ system.plan
  );
  conflictingSettings = lib.unique (
    map (leaf: lib.concatStringsSep "." leaf.path) conflicts
    ++ map (step: step.setting) plannedConflicts
  );
  firewall = cfg.applications.systemSettings.network.firewall;
  firewallOptions = firewall.options;
  existingFirewall = config.networking.applicationFirewall;
  firewallConflicts =
    lib.filterAttrs (name: value: value != null && existingFirewall.${name} != null)
      {
        enable = firewall.firewall;
        blockAllIncoming = firewallOptions.blockAllIncomingConnections;
        allowSigned = firewallOptions.automaticallyAllowBuiltInSoftwareToReceiveIncomingConnections;
        allowSignedApp =
          firewallOptions.automaticallyAllowDownloadedSignedSoftwareToReceiveIncomingConnections;
        enableStealthMode = firewallOptions.enableStealthMode;
      };
  snapshots = lib.unique (
    map (step: step.file) (lib.filter (step: step.op == "restore") (user.plan ++ system.plan))
  );
in
{
  options.system.settings =
    settings.module.optionTree {
      tree = catalog;
      scope = null;
    }
    // {
      ignoreWarnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Setting paths or relations whose dependency warnings should be
          suppressed. For example, use "applications.systemSettings.appearance.textHighlightColor"
          when its accent color is deliberately unmanaged
        '';
      };
    };

  config = {
    assertions =
      user.assertions
      ++ system.assertions
      ++ [
        {
          assertion = user.plan == [ ] || primaryUser != null;
          message = "Set system.primary.user to configure user settings";
        }
        {
          assertion = conflicts == [ ] && plannedConflicts == [ ];
          message = "Use either system.settings or system.defaults for each preference. Overlapping settings: ${lib.concatStringsSep ", " conflictingSettings}";
        }
        {
          assertion = firewallConflicts == { };
          message = "Use either system.settings or networking.applicationFirewall for each firewall setting";
        }
      ];
    warnings = user.warnings ++ system.warnings;
    system.activation.steps = {
      settings = {
        deps = [ "defaults" ];
        checks = lib.darwin.shell.commandLines (
          map (file: [
            "/usr/bin/plutil"
            "-lint"
            "--"
            file
          ]) snapshots
        );
        text = lib.optionalString (system.script != "") (
          lib.escapeShellArgs [
            (script "system" system)
          ]
        );
      };
      userSettings = {
        deps = [
          "settings"
          "userDefaults"
        ];
        text = lib.optionalString (primaryUser != null && user.script != "") (
          asUser primaryUser [
            (script "user" user)
          ]
        );
      };
      launchd.deps = [ "userSettings" ];
    };
  };
}

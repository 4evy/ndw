{
  config,
  lib,
  ...
}:
let
  cfg = config.system.defaults;
  inherit (lib.darwin.defaults) commands;
  inherit (lib.darwin.shell) asUser commandLines;
  domains = lib.darwin.defaults.domains cfg;
  systemCommands = commands { } domains.system;
  userCommands = commands { } domains.user ++ commands { currentHost = true; } domains.userByHost;
  user = if config.system.primary.user == null then "" else config.system.primary.user;
  dockCommands =
    commands { } { "com.apple.dock" = cfg.dock; }
    ++ commands { } { "com.apple.dock" = cfg.CustomUserPreferences."com.apple.dock" or { }; }
    ++ commands { currentHost = true; } {
      "com.apple.dock" = cfg.CustomUserPreferencesByHost."com.apple.dock" or { };
    };
  hasDock = dockCommands != [ ];

in
{
  imports = [
    ./activity.nix
    ./custom.nix
    ./launch.nix
    ./global/global.nix
    ./update.nix
    ./windows.nix
    ./clock.nix
    ./controlcenter.nix
    ./dock.nix
    ./finder.nix
    ./hitoolbox.nix
    ./ical.nix
    ./loginwindow.nix
    ./magicmouse.nix
    ./screencapture.nix
    ./screensaver.nix
    ./smb.nix
    ./spaces.nix
    ./trackpad.nix
    ./input.nix
    ./universalaccess.nix
    ./useractivityd.nix
  ];
  config = {
    assertions = [
      {
        assertion = userCommands == [ ] || config.system.primary.user != null;
        message = "Set system.primary.user to configure user defaults";
      }
    ];
    system.activation.steps = {
      defaults = {
        deps = [ "users" ];
        text = commandLines systemCommands;
      };
      userDefaults = {
        deps = [ "defaults" ];
        functions = lib.strings.optionalString hasDock ''
          defaults_dock_state() {
            # Dock bookmark data cannot be converted to JSON by plutil
            # A missing domain is normal before the first preference write
            ${
              asUser user [
                "/usr/bin/defaults"
                "read"
                "com.apple.dock"
              ]
            } 2>/dev/null || true
            ${lib.strings.optionalString
              (
                commands { currentHost = true; } {
                  "com.apple.dock" = cfg.CustomUserPreferencesByHost."com.apple.dock" or { };
                } != [ ]
              )
              ''
                printf '\nByHost\n'
                ${
                  asUser user [
                    "/usr/bin/defaults"
                    "-currentHost"
                    "read"
                    "com.apple.dock"
                  ]
                } 2>/dev/null || true
              ''
            }
          }
        '';
        text =
          lib.strings.optionalString hasDock ''
            defaults_dock_before=$(defaults_dock_state)
          ''
          + lib.strings.concatMapStringsSep "\n" (asUser user) userCommands;
      };
      launchd.deps = [ "userDefaults" ];
      dock = {
        # Restart after launchctl setenv so Dock inherits the new environment
        deps = [ "launchd" ];
        text = lib.strings.optionalString (user != "") (
          lib.strings.optionalString hasDock ''
            defaults_dock_after=$(defaults_dock_state)
          ''
          + ''
            if ${lib.strings.optionalString hasDock ''[[ $defaults_dock_before != "$defaults_dock_after" ]] || ''}[[ ''${launchd_user_environment_changed:-false} == true ]]; then
              /usr/bin/killall -qu ${lib.strings.escapeShellArg user} Dock || true
            fi
          ''
        );
      };
      extra.deps = [ "dock" ];
    };
  };
}

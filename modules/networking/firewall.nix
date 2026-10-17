{ config, lib, ... }:
let
  inherit (lib.darwin.options) mkDefaultOption mkNullableOption;
  cfg = config.networking.applicationFirewall;
  applications =
    option: paths:
    lib.strings.concatMapStringsSep "\n" (
      path:
      lib.darwin.shell.commandLines [
        [
          "/usr/libexec/ApplicationFirewall/socketfilterfw"
          "--add"
          path
        ]
        [
          "/usr/libexec/ApplicationFirewall/socketfilterfw"
          "--${option}"
          path
        ]
      ]
    ) (lib.lists.unique (map toString paths));

  socketfilterfw =
    option: value:
    lib.concatStringsSep " " [
      "/usr/libexec/ApplicationFirewall/socketfilterfw"
      "--${option}"
      (if value then "on" else "off")
    ];
in
{
  options.networking.applicationFirewall = {
    enable = mkNullableOption lib.types.bool "Whether to enable application firewall." // {
      example = true;
    };

    blockAllIncoming = mkNullableOption lib.types.bool "Whether to block all incoming connections." // {
      example = true;
    };

    allowSigned =
      mkNullableOption lib.types.bool "Whether to allow built-in software to receive incoming connections."
      // {
        example = true;
      };

    allowSignedApp =
      mkNullableOption lib.types.bool "Whether to allow downloaded signed software to receive incoming connections."
      // {
        example = true;
      };

    enableStealthMode = mkNullableOption lib.types.bool "Whether to enable stealth mode." // {
      example = true;
    };

    allowedApplications = mkDefaultOption (lib.types.listOf lib.types.path) [ ] ''
      Absolute paths to applications or executables allowed to receive
      incoming connections. Each path must exist during activation and is
      registered before it is unblocked. Shell variables are not expanded

      This does not enable the firewall. blockAllIncoming takes precedence
      over these exceptions. Removing an entry leaves its existing rule in
      place. Move it to blockedApplications to explicitly block it instead
    '';

    blockedApplications = mkDefaultOption (lib.types.listOf lib.types.path) [ ] ''
      Absolute paths to applications or executables blocked from receiving
      incoming connections. Each path must exist during activation and is
      registered before it is blocked. Shell variables are not expanded

      This does not enable the firewall. Removing an entry leaves its
      existing rule in place. Move it to allowedApplications to unblock it,
      or use socketfilterfw --remove to remove the explicit rule
    '';
  };

  config = {
    assertions = [
      {
        assertion =
          lib.lists.intersectLists (map toString cfg.allowedApplications) (
            map toString cfg.blockedApplications
          ) == [ ];
        message = "An application cannot appear in both networking.applicationFirewall.allowedApplications and blockedApplications";
      }
    ];
    system.activation.steps.networking.checks = lib.strings.concatMapStringsSep "\n" (path: ''
      if [[ ! -e ${lib.strings.escapeShellArg path} ]]; then
        printf >&2 'error: firewall application does not exist: %s\n' ${lib.strings.escapeShellArg path}
        exit 2
      fi
    '') (lib.lists.unique (map toString (cfg.allowedApplications ++ cfg.blockedApplications)));
    system.activation.steps.networking.text = ''
      echo "configuring application firewall..." >&2

      ${lib.optionalString (cfg.enable != null) (socketfilterfw "setglobalstate" cfg.enable)}
      ${lib.optionalString (cfg.blockAllIncoming != null) (
        socketfilterfw "setblockall" cfg.blockAllIncoming
      )}
      ${lib.optionalString (cfg.allowSigned != null) (socketfilterfw "setallowsigned" cfg.allowSigned)}
      ${lib.optionalString (cfg.allowSignedApp != null) (
        socketfilterfw "setallowsignedapp" cfg.allowSignedApp
      )}
      ${lib.optionalString (cfg.enableStealthMode != null) (
        socketfilterfw "setstealthmode" cfg.enableStealthMode
      )}

      ${applications "unblockapp" cfg.allowedApplications}
      ${applications "blockapp" cfg.blockedApplications}
    '';
  };
}

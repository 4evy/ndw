{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  inherit (lib.darwin.options) mkDefaultOption mkNullableOption;
  cfg = config.networking;

  hostnameRegEx = ''^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$'';

  emptyList = lst: if lst != [ ] then lst else [ "empty" ];

  onOff = cond: if cond then "on" else "off";

  command = lib.strings.escapeShellArgs;
  # Rewriting an unchanged name makes configd rebuild network state
  # A failed read must still set the name, even if the desired value is empty
  setName =
    name: value:
    optionalString (value != null) ''
      if ! networking_current_name=$(/usr/sbin/scutil --get ${name} 2>/dev/null) \
        || [[ $networking_current_name != ${escapeShellArg value} ]]; then
        /usr/sbin/scutil --set ${name} ${escapeShellArg value}
      fi
    '';
  setNetworkServices = optionalString (cfg.knownNetworkServices != [ ]) ''
    network_services=$(/usr/sbin/networksetup -listallnetworkservices)
    ${concatMapStringsSep "\n" (srv: ''
      # Match the whole service name, including disabled services
      if grep --fixed-strings --line-regexp --quiet -- ${escapeShellArg srv} <<< "$network_services" \
        || grep --fixed-strings --line-regexp --quiet -- ${escapeShellArg ("*" + srv)} <<< "$network_services"; then
        ${command (
          [
            "/usr/sbin/networksetup"
            "-setdnsservers"
            srv
          ]
          ++ emptyList cfg.dns
        )}
        ${command (
          [
            "/usr/sbin/networksetup"
            "-setsearchdomains"
            srv
          ]
          ++ emptyList cfg.search
        )}
        ${optionalString (cfg.dhcpClientId != null) (command [
          "/usr/sbin/networksetup"
          "-setdhcp"
          srv
          cfg.dhcpClientId
        ])}
      fi
    '') cfg.knownNetworkServices}
  '';

in

{
  imports = [ ./firewall.nix ];

  options = {
    networking.computerName =
      mkNullableOption types.str ''
        The user-friendly name for the system, set in System Preferences > Sharing > Computer Name.

        Setting this option is equivalent to running `/usr/sbin/scutil --set ComputerName`.

        This name can contain spaces and Unicode characters.
      ''
      // {
        example = "John's MacBook Pro";
      };

    networking.hostName =
      mkNullableOption (types.strMatching hostnameRegEx) ''
        The hostname of your system, as visible from the command line and used by local and remote
        networks when connecting through SSH and Remote Login.

        Setting this option is equivalent to running the command `/usr/sbin/scutil --set HostName`.

        (Note that networking.localHostName defaults to the value of this option.)
      ''
      // {
        example = "Johns-MacBook-Pro";
      };

    networking.localHostName =
      mkDefaultOption (types.nullOr (types.strMatching hostnameRegEx)) cfg.hostName ''
        The local hostname, or local network name, is displayed beneath the computer's name at the
        top of the Sharing preferences pane. It identifies your Mac to Bonjour-compatible services.

        Setting this option is equivalent to running the command `/usr/sbin/scutil --set LocalHostName`, where
        running, e.g., `/usr/sbin/scutil --set LocalHostName 'Johns-MacBook-Pro'`, would set
        the systems local hostname to "Johns-MacBook-Pro.local". The value of this option defaults
        to the value of the networking.hostName option.

        By default on macOS the local hostname is your computer's name with ".local" appended, with
        any spaces replaced with hyphens, and invalid characters omitted.
      ''
      // {
        example = "Johns-MacBook-Pro";
      };

    networking.domain =
      mkNullableOption types.str ''
        The domain.  It can be left empty if it is auto-detected through DHCP.
      ''
      // {
        example = "home.arpa";
      };

    networking.fqdn = mkOption {
      type = types.str;
      default =
        if (cfg.hostName != null && cfg.hostName != "" && cfg.domain != null) then
          "${cfg.hostName}.${cfg.domain}"
        else
          throw ''
            The FQDN is required but cannot be determined from `networking.hostName`
            and `networking.domain`. Please ensure these options are set properly or
            set `networking.fqdn` directly.
          '';
      defaultText = literalExpression ''"''${networking.hostName}.''${networking.domain}"'';
      description = ''
        The fully qualified domain name (FQDN) of this host. By default, it is
        the result of combining `networking.hostName` and `networking.domain.`

        Using this option will result in an evaluation error if the hostname is empty or
        no domain is specified.

        Modules that accept a mere `networking.hostName` but prefer a fully qualified
        domain name may use `networking.fqdnOrHostName` instead.
      '';
    };

    networking.fqdnOrHostName =
      mkDefaultOption (types.nullOr types.str) (if cfg.domain == null then cfg.hostName else cfg.fqdn) ''
        Either the fully qualified domain name (FQDN), or just the host name if
        it does not exists.

        This is a convenience option for modules to read instead of `fqdn` when
        a mere `hostName` is also an acceptable value. This option does not
        throw an error when `domain` is unset.
      ''
      // {
        readOnly = true;
        defaultText = literalExpression ''
          if cfg.domain == null then cfg.hostName else cfg.fqdn
        '';
      };

    networking.knownNetworkServices =
      mkDefaultOption (types.listOf types.str) [ ] ''
        List of networkservices that should be configured.

        To display a list of all the network services on the server's
        hardware ports, use {command}`networksetup -listallnetworkservices`.
      ''
      // {
        example = [
          "Wi-Fi"
          "Ethernet Adaptor"
          "Thunderbolt Ethernet"
        ];
      };

    networking.dhcpClientId =
      mkNullableOption types.str ''
        The DHCP client identifier to use when requesting an IP address from a DHCP server.

        If this option is set, it will be used by the system when requesting an IP address.
        If not set, no changes will be made.

        Set to the string "empty" to clear any previously configured client ID
        and restore the system default behavior.
      ''
      // {
        example = "my-client-id";
      };

    networking.dns =
      mkDefaultOption (types.listOf types.str) [ ]
        "The list of dns servers used when resolving domain names."
      // {
        example = [
          "8.8.8.8"
          "8.8.4.4"
          "2001:4860:4860::8888"
          "2001:4860:4860::8844"
        ];
      };

    networking.search =
      mkDefaultOption (types.listOf types.str) [ ]
        "The list of search paths used when resolving domain names.";

    networking.wakeOnLan.enable = mkNullableOption types.bool ''
      Enable Wake-on-LAN for the device.

      Battery powered devices may require being connected to power.
    '';
  };

  config = {

    warnings = [
      (mkIf (
        cfg.knownNetworkServices == [ ] && cfg.dns != [ ]
      ) "networking.knownNetworkServices is empty, dns servers will not be configured.")
      (mkIf (
        cfg.knownNetworkServices == [ ] && cfg.search != [ ]
      ) "networking.knownNetworkServices is empty, dns searchdomains will not be configured.")
      (mkIf (
        cfg.knownNetworkServices == [ ] && cfg.dhcpClientId != null
      ) "networking.knownNetworkServices is empty, dhcp client ID will not be configured.")
    ];

    system.activation.steps.networking = {
      deps = [ "run" ];
      runtimeInputs = lib.attrsets.attrValues { inherit (pkgs) gnugrep; };
      text = ''
        echo "configuring networking..." >&2

        ${setName "ComputerName" cfg.computerName}
        ${setName "HostName" cfg.hostName}
        ${setName "LocalHostName" cfg.localHostName}

        ${setNetworkServices}

        ${optionalString (cfg.wakeOnLan.enable != null) ''
          /usr/sbin/systemsetup -setWakeOnNetworkAccess '${onOff cfg.wakeOnLan.enable}'
        ''}

      '';
    };
    system.activation.steps.launchd.deps = [ "networking" ];
  };
}

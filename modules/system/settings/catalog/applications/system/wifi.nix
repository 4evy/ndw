{ settingsLib, ... }:
let
  page = settingsLib.systemPage "Wi‑Fi" "com.apple.settings.wifi";
  inherit (page) select toggle;

  inherit (settingsLib)
    system
    enum
    ;

  airport = system "SystemConfiguration/com.apple.airport.preferences";

  advancedCheckbox = settingsLib.checkbox advanced;
  advanced = settingsLib.sectionWith toggle {
    ui = "Advanced…";
    verify.open = [ "Advanced…" ];
  };
in
{
  askToJoinNetworks = select {
    ui = "Ask to join networks";
    storage = airport "JoinModeFallback";
    value = enum {
      Off = [ "DoNothing" ];
      Notify = [ "Notify" ];
      Ask = [ "Prompt" ];
    };
    choices = [
      "Ask"
      "Notify"
    ];
  };

  askToJoinHotspots = select {
    ui = "Ask to join hotspots";
    storage = airport "AutoHotspotMode";
    value = enum {
      Never = "Never";
      "Ask To Join" = "AskToJoin";
      Automatic = "Automatic";
    };
    choices = [
      "Never"
      "Ask To Join"
    ];
  };

  showLegacyNetworksAndOptions =
    advancedCheckbox "Show legacy networks and options" (airport "AllowLegacyNetworks")
      "AXCheckBox:wifi-show-legacy-networks";

  requireAdministratorAuthorizationTo = {
    changeNetworks = advancedCheckbox [
      "Require administrator authorization to"
      "Change networks"
    ] (airport "RequireAdminNetworkChange") "AXCheckBox:wifi-require-admin-network-change";
    turnWiFiOnOrOff = advancedCheckbox [
      "Require administrator authorization to"
      "Turn Wi‑Fi on or off"
    ] (airport "RequireAdminPowerToggle") "AXCheckBox:wifi-require-admin-power-toggle";
  };
}

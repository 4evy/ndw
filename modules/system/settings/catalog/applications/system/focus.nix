{ settingsLib, ... }:
let
  toggle = settingsLib.toggle setting;

  inherit (settingsLib)
    setting
    user
    bool
    inverted
    restarts
    ;
in
{
  shareAcrossDevices = toggle {
    ui = [
      "System Settings"
      "Focus"
      "Share across devices"
    ];
    storage = user "com.apple.donotdisturbd" "disableCloudSync";
    value = inverted bool;
    behaviors = [ (restarts "donotdisturbd") ];
    verify = {
      pane = "com.apple.settings.focus";
    };
  };
}

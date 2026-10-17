{ settingsLib, ... }:
let
  preference = settingsLib.preference toggle;
  page = (settingsLib.systemPage "General" "com.apple.settings.general").navigate "AirDrop & Continuity" open;
  inherit (page) select toggle;

  inherit (settingsLib)
    eachKey
    bool
    user
    byHost
    enum
    restarts
    ;

  open = [ "com.apple.systempreferences.general.airDropAndHandoff" ];

in
{
  airDrop = select {
    ui = "AirDrop";
    storage = user "com.apple.sharingd" "DiscoverableMode";
    value = enum {
      "No One" = "Off";
      "Contacts Only" = "Contacts Only";
      Everyone = "Everyone";
    };
    behaviors = [ (restarts "sharingd") ];
    choices = [
      "No One"
      "Contacts Only"
    ];
  };

  allowHandoffBetweenThisMacAndYourIcloudDevices =
    preference "Allow Handoff between this Mac and your iCloud devices"
      {
        advertising = byHost (user "com.apple.coreservices.useractivityd" "ActivityAdvertisingAllowed");
        receiving = byHost (user "com.apple.coreservices.useractivityd" "ActivityReceivingAllowed");
      }
      (eachKey bool);

  iPhoneWidgets = toggle {
    ui = "iPhone Widgets";
    storage = user "com.apple.chronod" "remoteWidgetsEnabled";
    behaviors = [ (restarts "chronod") ];
    control = "use-iphone-widgets";
  };

  airPlayReceiver = toggle {
    ui = "AirPlay Receiver";
    storage = byHost (user "com.apple.controlcenter" "AirplayReceiverEnabled");
    behaviors = [ (restarts "ControlCenter") ];
  };
}

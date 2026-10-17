{ settingsLib, ... }:
let
  page = settingsLib.page {
    ui = "System Settings";
    verify.pane = "com.apple.settings.displayAndBrightness";
  };
  inherit (page) setting select toggle;

  inherit (settingsLib)
    numberBetween
    user
    byHost
    mkKey
    bool
    inverted
    enum
    onlyWhen
    live
    ;

  option = name: "applications.systemSettings.displays.${name}";

  coreBrightness = mkKey {
    domain = "/var/root/Library/Preferences/com.apple.CoreBrightness";
    name = null;
  };

  advancedCheckbox = settingsLib.checkbox advanced;
  advanced = settingsLib.sectionWith toggle {
    ui = [
      "Displays"
      "Advanced…"
    ];
    click = true;
    verify.open = [ "Advanced…" ];
  };

  universalControl = name: byHost (user "com.apple.universalcontrol" name);
in
{
  trueTone = setting {
    ui = [
      "Displays"
      "True Tone"
    ];
    storage = coreBrightness;
    value = bool;
    apply = enabled: live.coreBrightness "CBTrueToneClient" "setEnabled" [ enabled ];
  };

  nightShift = {
    schedule = setting {
      ui = [
        "Displays"
        "Night Shift…"
        "Schedule"
      ];
      storage = coreBrightness;
      value = enum {
        Off = 0;
        "Sunset to Sunrise" = 1;
      };
      apply =
        mode:
        live.coreBrightness "CBBlueLightClient" "setMode" [
          {
            Off = 0;
            "Sunset to Sunrise" = 1;
          }
          .${mode}
        ];
    };

    colorTemperature = setting {
      ui = [
        "Displays"
        "Night Shift…"
        "Color temperature"
      ];
      description = "From less warm (0) to more warm (1).";
      storage = coreBrightness;
      value = numberBetween 0.0 1.0;
      apply =
        strength:
        live.coreBrightness "CBBlueLightClient" "setStrengthCommit" [
          strength
          true
        ];
    };
  };

  whenConnectedToTv = select {
    ui = [
      "Displays"
      "When connected to TV"
    ];
    storage = byHost (user "com.apple.windowserver.displays" "TVConnectPolicy");
    value = enum {
      "Ask What to Show" = 0;
      "Mirror Entire Screen" = 1;
      "Choose Window or App" = 2;
      "Use as Extended Display" = 4;
    };
    control = "When connected to TV";
    choices = [
      "Ask What to Show"
      "Mirror Entire Screen"
      "Use as Extended Display"
    ];
  };

  showResolutionsAsList =
    advancedCheckbox "Show resolutions as list"
      (user "com.apple.Displays-Settings.extension" "showListByDefault")
      "ShowResolutionsAsListToggle";

  universalControl = {
    allowPointerAndKeyboardToMoveBetweenNearbyDevices = advanced {
      ui = [
        "Link to Mac or iPad"
        "Allow your pointer and keyboard to move between any nearby Mac or iPad"
      ];
      storage = universalControl "Disable";
      value = inverted bool;
      control = "UniversalControlShareKeyboardToggle";
    };

    pushThroughTheEdgeOfADisplayToConnect = advanced {
      ui = [
        "Link to Mac or iPad"
        "Push through the edge of a display to connect a nearby Mac or iPad"
      ];
      storage = universalControl "DisableMagicEdges";
      value = inverted bool;
      control = "UniversalControlMagicEdgesToggle";
      relations = [
        (onlyWhen (option "universalControl.allowPointerAndKeyboardToMoveBetweenNearbyDevices") (
          allowed: allowed
        ) "it's part of moving the pointer and keyboard between devices")
      ];
    };
  };
}

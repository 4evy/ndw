{ settingsLib, ... }:
let
  page = settingsLib.systemPage [
    "Desktop & Dock"
    "Hot Corners…"
  ] "com.apple.settings.desktopAndDock";
  inherit (page) setting select;

  inherit (settingsLib)
    user
    enum
    flags
    restarts
    family
    onlyWhen
    ;

in
family
  {
    topLeft = {
      corner = "tl";
      label = "Top Left";
    };
    topRight = {
      corner = "tr";
      label = "Top Right";
    };
    bottomLeft = {
      corner = "bl";
      label = "Bottom Left";
    };
    bottomRight = {
      corner = "br";
      label = "Bottom Right";
    };
  }
  (
    {
      name,
      corner,
      label,
    }:
    {
      action = select {
        ui = "${label} Hot Corner";
        storage = user "com.apple.dock" "wvous-${corner}-corner";
        value = enum {
          "-" = 1;
          "Mission Control" = 2;
          "Application Windows" = 3;
          "Desktop" = 4;
          "Start Screen Saver" = 5;
          "Disable Screen Saver" = 6;
          "Put Display to Sleep" = 10;
          "Apps" = 11;
          "Notification Center" = 12;
          "Lock Screen" = 13;
          "Quick Note" = 14;
        };
        behaviors = [ (restarts "Dock") ];
        control = "${label} Hot Corner";
        choices = [
          "-"
          "Mission Control"
          "Quick Note"
        ];
        verify.open = [ "Hot Corners…" ];
      };

      modifiers = setting {
        ui = [
          "${label} Hot Corner"
          "Modifier keys"
        ];
        storage = user "com.apple.dock" "wvous-${corner}-modifier";
        value = flags {
          shift = 131072;
          control = 262144;
          option = 524288;
          command = 1048576;
        };
        behaviors = [ (restarts "Dock") ];
        relations = [
          (onlyWhen "applications.systemSettings.desktopAndDock.hotCorners.${name}.action" (
            action: action != "-"
          ) "a corner without an action doesn't use modifier keys")
        ];
      };
    }
  )

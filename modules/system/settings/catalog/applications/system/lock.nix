{ settingsLib, ... }:
let
  preference = settingsLib.preference toggle;
  page = settingsLib.systemPage "Lock Screen" "com.apple.settings.lockScreen";
  inherit (page) setting select toggle;

  inherit (settingsLib)
    boolAs
    system
    bool
    inverted
    text
    enum
    live
    ;

  loginWindow = system "com.apple.loginwindow";

  displayTimes = {
    "For 1 minute" = 1;
    "For 2 minutes" = 2;
    "For 3 minutes" = 3;
    "For 5 minutes" = 5;
    "For 10 minutes" = 10;
    "For 20 minutes" = 20;
    "For 30 minutes" = 30;
    "For 1 hour" = 60;
    "For 1 hour, 30 minutes" = 90;
    "For 2 hours" = 120;
    "For 2 hours, 30 minutes" = 150;
    "For 3 hours" = 180;
    Never = 0;
  };

  turnDisplayOff =
    {
      ui,
      source,
      dictionary,
    }:
    select {
      ui = [
        ui
      ];
      storage = system "com.apple.PowerManagement" dictionary;
      value = enum displayTimes;
      apply = time: "/usr/bin/pmset -${source} displaysleep ${toString displayTimes.${time}}";
      reads = {
        command = live.pmsetValue dictionary "displaysleep";
        values = displayTimes;
      };
      control = "AXPopUpButton:${ui}";
      choices = [
        "For 10 minutes"
        "Never"
      ];
    };

in
{
  turnDisplayOffOnBatteryWhenInactive = turnDisplayOff {
    ui = "Turn display off on battery when inactive";
    source = "b";
    dictionary = "Battery Power";
  };

  turnDisplayOffOnPowerAdapterWhenInactive = turnDisplayOff {
    ui = "Turn display off on power adapter when inactive";
    source = "c";
    dictionary = "AC Power";
  };

  showPasswordHints = preference "Show password hints" (loginWindow "RetriesUntilHint") (boolAs 3 0);

  messageWhenLocked = setting {
    ui = [
      "Show message when locked"
      "Set…"
    ];
    description = "The message shown on the lock screen and login window. Unset shows none.";
    storage = loginWindow "LoginwindowText";
    value = text;
    verify.expect = {
      "Back soon" = {
        "AXCheckBox:Show message when locked" = 1;
      };
    };
  };

  loginWindowShows = page.radio {
    ui = "Login window shows";
    storage = loginWindow "SHOWFULLNAME";
    value = enum {
      "List of users" = false;
      "Name and password" = true;
    };
  };

  showTheSleepRestartAndShutDownButtons =
    preference "Show the Sleep, Restart, and Shut Down buttons" (loginWindow "PowerOffDisabled")
      (inverted bool);
}

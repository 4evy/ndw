{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Menu Bar" "com.apple.settings.controlCenter";
  inherit (page) setting select toggle;

  inherit (settingsLib)
    boolKeys
    bool
    boolAs
    global
    user
    byHost
    enum
    inDict
    member
    snapshot
    restarts
    onlyWhen
    live
    ;

  option = name: "applications.systemSettings.menuBar.${name}";

  clock = name: user "com.apple.menuextra.clock" name;
  groupContainer = group: "~/Library/Group Containers/${group}/Library/Preferences/${group}";

  clockSwitch =
    {
      ui,
      key,
      control,
      relations ? [ ],
    }:
    toggle {
      inherit relations;
      ui = [
        "Clock Options…"
        ui
      ];
      storage = clock key;
      behaviors = [ (restarts "ControlCenter") ];
      inherit control;
      click = true;
      verify = if control == null then null else { open = [ "Clock Options…" ]; };
    };

  digitalOnly = onlyWhen (option "clock.style") (
    style: style == "Digital"
  ) "an analog clock doesn't show it";

  # Control Center keeps each module's menu bar state as a bitmask: 2 shown,
  # 8 hidden, 16 Always Show
  controlCenter = name: byHost (user "com.apple.controlcenter" name);

  checkbox = id: "AXCheckBox:controlcenter-${id}-id";
  popup = id: "AXPopUpButton:controlcenter-${id}-id";

  moduleWithMenu =
    ui: key: id:
    setting {
      ui = [
        "Menu Bar Controls"
        ui
      ];
      storage = controlCenter key;
      value = enum {
        "Don't Show" = 24;
        "Show When Active" = 2;
        "Always Show" = 18;
      };
      behaviors = [ (restarts "ControlCenter") ];
      verify.expect = {
        "Don't Show" = {
          ${checkbox id} = 0;
        };
        "Show When Active" = {
          ${checkbox id} = 1;
          ${popup id} = "Show When Active";
        };
        "Always Show" = {
          ${checkbox id} = 1;
          ${popup id} = "Always Show";
        };
      };
    };

  persistentModule = module 18 24;
  activeModule = module 2 8;

  module =
    shown: hidden: ui: key: id:
    toggle {
      ui = [
        "Menu Bar Controls"
        ui
      ];
      storage = controlCenter key;
      value = boolAs shown hidden;
      behaviors = [ (restarts "ControlCenter") ];
      control = checkbox id;
    };
in
{
  autoHideAndShowTheMenuBar = select {
    ui = "Automatically hide and show the menu bar";
    storage = {
      hidden = global "_HIHideMenuBar";
      visibleInFullScreen = global "AppleMenuBarVisibleInFullscreen";
      choice = user "com.apple.controlcenter" "AutoHideMenuBarOption";
    };
    value = enum {
      Always = {
        hidden = true;
        visibleInFullScreen = false;
        choice = 0;
      };
      "On Desktop Only" = {
        hidden = true;
        visibleInFullScreen = true;
        choice = 1;
      };
      "In Full Screen Only" = {
        hidden = false;
        visibleInFullScreen = false;
        choice = 2;
      };
      Never = {
        hidden = false;
        visibleInFullScreen = true;
        choice = 3;
      };
    };
    control = "autohide-menubar";
  };

  showMenuBarBackground = toggle {
    ui = "Show menu bar background";
    storage = global "SLSMenuBarUseBlurredAppearance";
    control = "Show menu bar background";
    verify = {
      # The switch sits under the window's title bar, where a click doesn't
      # reach it
      operate = [
        "press"
        "Show menu bar background"
      ];
    };
  };

  clock = {
    showDate = toggle {
      ui = [
        "Clock Options…"
        "Show date"
      ];
      storage = clock "ShowDate";
      value = boolAs 1 2;
      behaviors = [ (restarts "ControlCenter") ];
      control = "show-date";
      click = true;
      verify = {
        open = [ "Clock Options…" ];
      };
    };

    showTheDayOfTheWeek = clockSwitch {
      ui = "Show the day of the week";
      key = "ShowDayOfWeek";
      control = "show-day-of-week";
    };

    style = page.radio {
      ui = [
        "Clock Options…"
        "Style"
      ];
      storage = clock "IsAnalog";
      value = enum {
        Digital = false;
        Analog = true;
      };
      behaviors = [ (restarts "ControlCenter") ];

      verify = {
        open = [ "Clock Options…" ];
        operate = [
          [
            "press"
            "AXRadioButton:Analog"
          ]
          [
            "press"
            "AXRadioButton:Digital"
          ]
        ];
      };
    };

    flashTheTimeSeparators = clockSwitch {
      ui = "Flash the time separators";
      key = "FlashDateSeparators";
      control = "flash-separators";
      relations = [ digitalOnly ];
    };

    displayTheTimeWithSeconds = clockSwitch {
      ui = "Display the time with seconds";
      key = "ShowSeconds";
      control = "show-seconds";
      relations = [ digitalOnly ];
    };

    showAmPm = clockSwitch {
      ui = "Show AM/PM";
      key = "ShowAMPM";
      control = null;
    };

    announceTheTime =
      let
        timeAnnouncements = user "com.apple.speech.synthesis.general.prefs" "TimeAnnouncementPrefs";
        entry =
          ui: control: value:
          setting {
            inherit value;
            ui = [
              "Clock Options…"
              ui
            ];
            storage = timeAnnouncements;
            canUnset = false;
            verify = {
              open = [ "Clock Options…" ];
              expect = lib.mapAttrs (_: shown: { ${control} = shown; }) (
                if value.kind == "bool" then
                  {
                    true = 1;
                    false = 0;
                  }
                else
                  {
                    "On the hour" = "On the hour";
                    "On the quarter hour" = "On the quarter hour";
                  }
              );
            };
          };
      in
      {
        enable = entry "Announce the time" "announce-time" (inDict "TimeAnnouncementsEnabled" bool);

        interval = entry "Interval" "time-interval" (
          inDict "TimeAnnouncementsIntervalIdentifier" (enum {
            "On the hour" = "EveryHourInterval";
            "On the half hour" = "EveryHalfHourInterval";
            "On the quarter hour" = "EveryQuarterHourInterval";
          })
        );
      };
  };

  wifi = persistentModule "Wi‑Fi" "WiFi" "wifi";
  bluetooth = persistentModule "Bluetooth" "Bluetooth" "bluetooth";
  airdrop = persistentModule "AirDrop" "AirDrop" "airdrop";
  battery = activeModule "Battery" "Battery" "battery";
  timeMachine = toggle {
    ui = [
      "Menu Bar Controls"
      "Time Machine"
    ];
    storage = user "com.apple.systemuiserver" "menuExtras";
    value = member { item = "/System/Library/CoreServices/Menu Extras/TimeMachine.menu"; };
    behaviors = [ (restarts "SystemUIServer") ];
    control = checkbox "timeMachine";
    verify = {
      settle = 5;
    };
  };
  keyboardBrightness = activeModule "Keyboard Brightness" "KeyboardBrightness" "keyboardBrightness";

  focusModes = moduleWithMenu "Focus" "FocusModes" "focus";
  screenMirroring = moduleWithMenu "Screen Mirroring" "ScreenMirroring" "screenMirroring";
  display = moduleWithMenu "Display" "Display" "display";
  sound = moduleWithMenu "Sound" "Sound" "sound";
  nowPlaying = moduleWithMenu "Now Playing" "NowPlaying" "nowPlaying";
  timer = moduleWithMenu "Timer" "Timer" "timer";

  siri = toggle {
    ui = [
      "Menu Bar Controls"
      "Siri"
    ];
    storage = {
      module = controlCenter "Siri";
      statusMenu = user "com.apple.Siri" "StatusMenuVisible";
    };
    value = boolKeys {
      module = boolAs 2 8;
      statusMenu = bool;
    };
    behaviors = [ (restarts "ControlCenter") ];
    control = checkbox "siri";
  };

  textInput = toggle {
    ui = [
      "Menu Bar Controls"
      "Text Input"
    ];
    storage = user "com.apple.TextInputMenu" "visible";
    behaviors = [ (restarts "TextInputMenuAgent") ];
    control = checkbox "textInput";
  };

  fastUserSwitching = module 3 9 "Fast User Switching" "UserSwitcher" "userSwitcher";

  fastUserSwitchingShowAs = setting {
    ui = [
      "Menu Bar Controls"
      "Fast User Switching"
      "Show in Menu Bar"
    ];
    storage = global "userMenuExtraStyle";
    value = enum {
      "Full Name" = 0;
      "Account Name" = 1;
      Icon = 2;
    };
    behaviors = [ (restarts "ControlCenter") ];
    relations = [
      (onlyWhen (option "fastUserSwitching") (
        shown: shown
      ) "it's how Fast User Switching shows in the menu bar")
    ];
  };

  batteryOptions = {
    showPercentage = toggle {
      ui = [
        "Menu Bar Controls"
        "Battery Options…"
        "Show Percentage"
      ];
      storage = controlCenter "BatteryShowPercentage";
      behaviors = [ (restarts "ControlCenter") ];
      control = "show-battery-percentage-switch";
      verify.open = [ "Battery Options…" ];
    };

    showEnergyMode = select {
      ui = [
        "Menu Bar Controls"
        "Battery Options…"
        "Show Energy Mode"
      ];
      storage = controlCenter "BatteryShowEnergyMode";
      value = enum {
        "When Active" = 0;
        Always = 1;
      };
      behaviors = [ (restarts "ControlCenter") ];
      control = "Show Energy Mode";
      choices = [
        "When Active"
        "Always"
      ];
      verify.open = [ "Battery Options…" ];
    };
  };

  showSuggestionsInControlGallery = toggle {
    ui = "Show suggestions in Control Gallery";
    storage = controlCenter "ShowSuggestions";
    behaviors = [ (restarts "ControlCenter") ];
    control = "Show suggestions in Control Gallery";
    click = true;
  };

  recentDocumentsApplicationsAndServers =
    let
      amounts = {
        None = 0;
        "5" = 5;
        "10" = 10;
        "15" = 15;
        "20" = 20;
        "30" = 30;
        "50" = 50;
      };
    in
    select {
      ui = "Recent documents, applications, and servers";
      # NumberOfRecents only mirrors the limit, which the shared file lists keep
      storage = user "com.apple.controlcenter" "NumberOfRecents";
      value = enum amounts;
      apply = label: [
        (live.recentItems amounts.${label})
        "/usr/bin/defaults write com.apple.controlcenter NumberOfRecents -int ${toString amounts.${label}}"
      ];
      canUnset = true;
      control = "recents";
      choices = [
        "None"
        "5"
        "10"
      ];
    };

  # TODO: Verify Spotlight's icon when its launch agent is available, which the
  # current Campo session on build 26A428 does not load
  layout = settingsLib.setting {
    ui = "Menu bar";
    description = ''
      Which apps' items show in the menu bar and their order, as arranged by
      hand, including the Siri app's icon. Legacy Siri and Spotlight state
      is also captured, but Spotlight's icon has not been verified while the
      legacy Spotlight agent is unavailable. Save the layout into your
      configuration with
      `darwin-settings-capture applications.systemSettings.menuBar.layout <directory>`
      and set this option to that directory. Control Center's own contents
      can't be declared.
    '';
    storage = {
      applications = user (groupContainer "group.com.apple.controlcenter") "trackedApplications";
      positions = user (groupContainer "com.apple.MenuBar") "TrailingItemPreferredPositions";
      showSiri = user (groupContainer "group.com.apple.controlcenter") "showSiri";
      siriApp = user "com.apple.campo" "NSStatusItem VisibleCC Item-0";
      siriModule = controlCenter "Siri";
      siriStatusMenu = user "com.apple.Siri" "StatusMenuVisible";
      showSpotlight = user (groupContainer "group.com.apple.controlcenter") "showSpotlight";
      spotlightModule = controlCenter "Spotlight";
    };
    value = snapshot // {
      # Earlier captures lack the Siri app, module, and status menu keys
      encode =
        keys: directory:
        snapshot.encode (lib.filterAttrs (
          name: _:
          !(builtins.elem name [
            "siriApp"
            "siriModule"
            "spotlightModule"
            "siriStatusMenu"
          ])
          || builtins.pathExists "${directory}/${name}.plist"
        ) keys) directory;
    };
    # Group-container writes use file paths, so refresh the preferences cache
    # before reloading the processes that arrange menu bar items
    behaviors = [
      (restarts "cfprefsd")
      (restarts "ControlCenter")
      # The Siri app reads visibility when it creates its status item
      (
        context: plan:
        if context.value == "unset" || builtins.pathExists "${context.value}/siriApp.plist" then
          restarts "Siri AI" context plan
        else
          plan
      )
    ];
  };
}

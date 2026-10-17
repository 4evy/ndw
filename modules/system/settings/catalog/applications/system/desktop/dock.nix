{ settingsLib, ... }:
let
  page = settingsLib.systemPage [ "Desktop & Dock" "Dock" ] "com.apple.settings.desktopAndDock";
  inherit (page) setting select toggle;

  inherit (settingsLib)
    numberBetween
    user
    global
    stored
    bool
    enum
    snapshot
    restarts
    restartsDiscardingItsState
    implies
    ;

  option = name: "applications.systemSettings.desktopAndDock.dock.${name}";

  dock = name: user "com.apple.dock" name;
  restartsDock = restarts "Dock";

  dockSwitchCheckbox = settingsLib.checkbox dockSwitch;
  dockSwitch = settingsLib.sectionWith toggle {
    behaviors = [ restartsDock ];
    click = true;
  };

  slider = size: (size - 16) / 112.0;
in
{
  size = setting {
    ui = "Size";
    description = "Icon size in points.";
    storage = stored "float" (dock "tilesize");
    value = numberBetween 16 128;
    behaviors = [ restartsDock ];
    verify.expect = {
      "16" = {
        "Dock Size" = slider 16;
      };
      "48" = {
        "Dock Size" = slider 48;
      };
      "128" = {
        "Dock Size" = slider 128;
      };
    };
  };

  magnification = {
    # System Settings has no separate switch for this
    enabled = setting {
      ui = "Magnification";
      storage = dock "magnification";
      value = bool;
      behaviors = [ restartsDock ];
      verify = {
        expect.false = {
          "Dock Magnification Size" = 0;
        };
      };
    };

    size = setting {
      ui = [
        "Magnification"
        "Size"
      ];
      description = "Magnified icon size in points.";
      storage = stored "float" (dock "largesize");
      value = numberBetween 16 128;
      behaviors = [ restartsDock ];
      relations = [
        (implies (option "magnification.enabled") true
          "moving the slider off \"Off\" turns magnification on"
        )
      ];
      verify.expect = {
        "72" = {
          "Dock Magnification Size" = slider 72;
        };
        "128" = {
          "Dock Magnification Size" = slider 128;
        };
      };
    };
  };

  dockPositionOnScreen = select {
    ui = "Dock position on screen";
    storage = dock "orientation";
    value = enum {
      Left = "left";
      Bottom = "bottom";
      Right = "right";
    };
    behaviors = [ restartsDock ];
    control = "position";
  };

  minimizedWindowAnimation = select {
    ui = "Minimized window animation";
    storage = dock "mineffect";
    value = enum {
      "Genie Effect" = "genie";
      "Scale Effect" = "scale";
    };
    behaviors = [ restartsDock ];
    control = "minimize-windows";
  };

  windowTitleBarDoubleClickAction = select {
    ui = "Window title bar double-click action";
    storage = global "AppleActionOnDoubleClick";
    value = enum {
      Fill = "Fill";
      Zoom = "Maximize";
      Minimize = "Minimize";
      "No Action" = "None";
    };
    control = "double-click";
  };

  minimizeWindowsIntoApplicationIcon =
    dockSwitchCheckbox "Minimize windows into application icon" (dock "minimize-to-application")
      "minimize-into-app";

  automaticallyHideAndShowTheDock = {
    enabled =
      dockSwitchCheckbox "Automatically hide and show the Dock" (dock "autohide")
        "auto-hide-dock";

    delay = setting {
      ui = [
        "Automatically hide and show the Dock"
        "Delay"
      ];
      description = "Seconds before a hidden Dock appears when the pointer reaches it.";
      storage = stored "float" (dock "autohide-delay");
      value = numberBetween 0.0 10.0;
      behaviors = [ restartsDock ];
    };

    duration = setting {
      ui = [
        "Automatically hide and show the Dock"
        "Animation duration"
      ];
      description = "How long the Dock takes to slide in and out, in seconds; 0 turns the animation off.";
      storage = stored "float" (dock "autohide-time-modifier");
      value = numberBetween 0.0 10.0;
      behaviors = [ restartsDock ];
    };
  };

  animateOpeningApplications =
    dockSwitchCheckbox "Animate opening applications" (dock "launchanim")
      "animate-app-opening";

  showIndicatorsForOpenApplications =
    dockSwitchCheckbox "Show indicators for open applications" (dock "show-process-indicators")
      "show-indicators";

  showSuggestedAndRecentAppsInDock =
    dockSwitchCheckbox "Show suggested and recent apps in Dock" (dock "show-recents")
      "show-recents";

  contents = settingsLib.setting {
    ui = "Dock";
    description = ''
      The apps on the left of the Dock's separator and the folders and stacks on the right, as
      arranged in the Dock. Save them into your configuration with
      `darwin-settings-capture applications.systemSettings.desktopAndDock.dock.contents <directory>`
      and set this option to that directory. Apps that aren't installed show as question marks.
    '';
    storage = {
      apps = dock "persistent-apps";
      others = dock "persistent-others";
    };
    value = snapshot;
    # The Dock saves its contents when it quits, which would overwrite what
    # was just restored
    behaviors = [ (restartsDiscardingItsState "Dock") ];
  };
}

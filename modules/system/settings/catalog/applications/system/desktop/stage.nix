{ settingsLib, ... }:
let
  page = settingsLib.systemPage [
    "Desktop & Dock"
    "Desktop & Stage Manager"
  ] "com.apple.settings.desktopAndDock";
  inherit (page) select toggle;

  inherit (settingsLib)
    user
    bool
    inverted
    enum
    ;

  windowManager = name: user "com.apple.WindowManager" name;

  switch = settingsLib.sectionWith toggle {
    click = true;
  };
in
{
  showItems = {
    onDesktop = switch {
      ui = [
        "Show items"
        "On Desktop"
      ];
      storage = windowManager "StandardHideDesktopIcons";
      value = inverted bool;
      control = "show-items-on-desktop";
    };
    inStageManager = switch {
      ui = [
        "Show items"
        "In Stage Manager"
      ];
      storage = windowManager "HideDesktop";
      value = inverted bool;
      control = "show-items-in-stage-manager";
    };
  };

  clickWallpaperToRevealDesktop = select {
    ui = "Click wallpaper to show desktop";
    storage = windowManager "EnableStandardClickToShowDesktop";
    value = enum {
      Always = true;
      "Only in Stage Manager" = false;
    };
    control = "click-wallpaper-to-reveal-desktop";
  };

  stageManager = switch {
    ui = "Stage Manager";
    storage = windowManager "GloballyEnabled";
    control = "stage-manager-on";
    # Turning it on in System Settings asks for confirmation in a separate
    # dialog first
    click = false;
  };

  showRecentAppsInStageManager = switch {
    ui = "Show recent apps in Stage Manager";
    storage = windowManager "AutoHide";
    value = inverted bool;
    control = "recent-applications";
  };

  showWindowsFromAnApplication = select {
    ui = "Show windows from an application";
    storage = windowManager "AppWindowGroupingBehavior";
    value = enum {
      "All at Once" = 1;
      "One at a Time" = 0;
    };
    control = "show-windows-from-application";
  };
}

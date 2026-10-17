{ settingsLib, ... }:
let
  page = settingsLib.systemPage [ "Desktop & Dock" "Widgets" ] "com.apple.settings.desktopAndDock";
  inherit (page) select toggle;

  inherit (settingsLib)
    user
    bool
    inverted
    enum
    ;

  showWidgetsCheckbox = settingsLib.checkbox showWidgets;
  showWidgets = settingsLib.sectionWith toggle {
    value = inverted bool;
    click = true;
  };
in
{
  showWidgets = {
    onDesktop = showWidgetsCheckbox [
      "Show Widgets"
      "On Desktop"
    ] (user "com.apple.WindowManager" "StandardHideWidgets") "show-desktop-widgets";
    inStageManager = showWidgetsCheckbox [
      "Show Widgets"
      "In Stage Manager"
    ] (user "com.apple.WindowManager" "StageManagerHideWidgets") "show-stage-manager-widgets";
  };

  dimWidgetsOnDesktop = select {
    ui = "Dim widgets on desktop";
    storage = user "com.apple.widgets" "widgetAppearance";
    value = enum {
      Always = 0;
      Never = 1;
      Automatically = 2;
    };
    control = "widget-style";
  };

}

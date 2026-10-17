{ settingsLib, ... }:
let
  page = settingsLib.systemPage [ "Desktop & Dock" "Windows" ] "com.apple.settings.desktopAndDock";
  inherit (page) select toggle;

  inherit (settingsLib)
    user
    global
    bool
    inverted
    enum
    ;

  switchCheckbox = settingsLib.checkbox switch;
  switch = args: toggle ({ click = true; } // args);
in
{
  preferTabsWhenOpeningDocuments = select {
    ui = "Prefer tabs when opening documents";
    storage = global "AppleWindowTabbingMode";
    value = enum {
      Never = "manual";
      Always = "always";
      "In Full Screen" = "fullscreen";
    };
    control = "prefer-tabs";
  };

  askToKeepChangesWhenClosingDocuments =
    switchCheckbox "Ask to keep changes when closing documents" (global "NSCloseAlwaysConfirmsChanges")
      "ask-to-save-changes";

  closeWindowsWhenQuittingAnApplication = switch {
    ui = "Close windows when quitting an application";
    storage = global "NSQuitAlwaysKeepsWindows";
    value = inverted bool;
    control = "restore-Windows";
  };

  dragWindowsToLeftOrRightEdgeOfScreenToTile =
    switchCheckbox "Drag windows to left or right edge of screen to tile"
      (user "com.apple.WindowManager" "EnableTilingByEdgeDrag")
      "tile-on-edge-drag";

  dragWindowsToMenuBarToFillScreen =
    switchCheckbox "Drag windows to menu bar to fill screen"
      (user "com.apple.WindowManager" "EnableTopTilingByEdgeDrag")
      "tile-on-top-edge-drag";

  holdOptionKeyWhileDraggingWindowsToTile =
    switchCheckbox "Hold ⌥ key while dragging windows to tile"
      (user "com.apple.WindowManager" "EnableTilingOptionAccelerator")
      "tile-option-accelerator";

  tiledWindowsHaveMargins =
    switchCheckbox "Tiled windows have margins"
      (user "com.apple.WindowManager" "EnableTiledWindowMargins")
      "tile-margins";
}

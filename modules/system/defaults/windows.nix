{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.WindowManager = {
    GloballyEnabled = mkNullableOption types.bool ''
      Enable Stage Manager
      Stage Manager arranges your recent windows into a single strip for reduced clutter and quick access. Default is false.
    '';

    EnableStandardClickToShowDesktop = mkNullableOption types.bool ''
      Click wallpaper to reveal desktop
      Clicking your wallpaper will move all windows out of the way to allow access to your desktop items and widgets. Default is true.
      false means "Only in Stage Manager"
      true means "Always"
    '';

    AutoHide = mkNullableOption types.bool ''
      Auto hide stage strip showing recent apps. Default is false.
    '';

    # WindowManager's AppWindowGroupingBehavior stores an integer enum
    # Its rawValue initializer accepts 0, 1, and 2
    AppWindowGroupingBehavior =
      mkNullableOption
        (types.either types.bool (
          types.enum [
            0
            1
            2
          ]
        ))
        ''
          Grouping strategy when showing windows from an application in Stage
          Manager. Zero means "One at a time" and one means "All at once".
          Mode two is the native single-window mode with promotion

          Boolean false writes zero and true writes one for compatibility.
          Null leaves the current preference unchanged
        ''
      // {
        apply = lib.trivial.mapNullable (
          value: if builtins.isBool value then (if value then 1 else 0) else value
        );
      };

    StandardHideDesktopIcons = mkNullableOption types.bool ''
      Hide items on desktop.
    '';

    HideDesktop = mkNullableOption types.bool ''
      Hide items in Stage Manager.
    '';

    EnableTilingByEdgeDrag = mkNullableOption types.bool ''
      Enable dragging windows to screen edges to tile them. The default is true.
    '';

    EnableTopTilingByEdgeDrag = mkNullableOption types.bool ''
      Enable dragging windows to the menu bar to fill the screen. The default is true.
    '';

    EnableTilingOptionAccelerator = mkNullableOption types.bool ''
      Enable holding alt to tile windows. The default is true.
    '';

    EnableTiledWindowMargins = mkNullableOption types.bool ''
      Enable window margins when tiling windows. The default is true.
    '';

    TiledWindowSpacing = mkNullableOption types.numbers.nonnegative ''
      Spacing in points between tiled windows when tiled window margins are
      enabled. Null leaves the current preference unchanged
    '';

    TilingHotzoneDelay = mkNullableOption types.numbers.nonnegative ''
      Delay in seconds before dragging a window to a tiling region triggers
      tiling. Null leaves the current preference unchanged
    '';

    StandardHideWidgets = mkNullableOption types.bool ''
      Hide widgets on desktop.
    '';

    StageManagerHideWidgets = mkNullableOption types.bool ''
      Hide widgets in Stage Manager.
    '';
  };
}

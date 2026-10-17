{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
  threeState = mkNullableOption (
    lib.types.enum [
      0
      1
      2
    ]
  );
  toggleGesture = mkNullableOption (
    lib.types.enum [
      0
      2
    ]
  );
in

{
  options.system.defaults.trackpad = {
    Clicking = mkNullableOption types.bool ''
      Whether to enable tap to click. The default is false.
    '';

    Dragging = mkNullableOption types.bool ''
      Whether to enable tap to drag. The default is false.
    '';

    TrackpadRightClick = mkNullableOption types.bool ''
      Whether to enable trackpad right click (two-finger tap/click).
      The default is false.
    '';

    TrackpadThreeFingerDrag = mkNullableOption types.bool ''
      Whether to enable three-finger drag. The default is false.
    '';

    ActuationStrength =
      mkNullableOption
        (types.enum [
          0
          1
        ])
        ''
          0 to enable Silent Clicking, 1 to disable. The default is 1.
        '';

    FirstClickThreshold = threeState ''
      For normal click: 0 for light clicking, 1 for medium, 2 for firm.
      The default is 1.
    '';

    SecondClickThreshold = threeState ''
      For force touch: 0 for light clicking, 1 for medium, 2 for firm.
      The default is 1.
    '';

    TrackpadThreeFingerTapGesture = toggleGesture ''
      Whether to enable three-finger tap gesture: 0 to disable, 2 to trigger Look up & data detectors.
      The default is 2.
    '';

    ActuateDetents = mkNullableOption types.bool ''
      Whether to enable haptic feedback. The default is true.
    '';

    DragLock = mkNullableOption types.bool ''
      Whether to enable drag lock. The default is false.
    '';

    ForceSuppressed = mkNullableOption types.bool ''
      Whether to disable force click. The default is false.
    '';

    TrackpadCornerSecondaryClick = threeState ''
      Whether to enable secondary click: 0 to disable, 1 to set bottom-left corner, 2 to set bottom-right corner.
      The default is 0.
    '';

    TrackpadFourFingerHorizSwipeGesture = toggleGesture ''
      Whether to enable four-finger horizontal swipe gesture: 0 to disable, 2 to swipe between full-screen applications.
      The default is 0.
    '';

    TrackpadFourFingerPinchGesture = toggleGesture ''
      Whether to enable four-finger pinch gesture (spread shows the Desktop, pinch shows the Launchpad): 0 to disable, 2 to enable.
      The default is 0.
      This setting interacts with `system.defaults.dock.showDesktopGestureEnabled` and `system.defaults.dock.showLaunchpadGestureEnabled` to determine whether gestures are enabled for the Desktop, Launchpad, or both.
    '';

    TrackpadFourFingerVertSwipeGesture = toggleGesture ''
      0 to disable four finger vertical swipe gestures, 2 to enable (down for Mission Control, up for App Exposé).
      The default is 2.
      When both three- and four-finger vertical swipe gestures are enabled, the three-finger variant takes precedence. This setting interacts with `system.defaults.dock.showAppExposeGestureEnabled` and `system.defaults.dock.showMissionControlGestureEnabled` to determine whether vertical swipe gestures are enabled for App Exposé, Mission Control, or both.
    '';

    TrackpadMomentumScroll = mkNullableOption types.bool ''
      Whether to use inertia when scrolling. The default is true.
    '';

    TrackpadPinch = mkNullableOption types.bool ''
      Whether to enable two-finger pinch gesture for zooming in and out.
      The default is false.
    '';

    TrackpadRotate = mkNullableOption types.bool ''
      Whether to enable two-finger rotation gesture. The default is false.
    '';

    TrackpadThreeFingerHorizSwipeGesture = threeState ''
      Whether to enable three-finger horizontal swipe gesture: 0 to disable, 1 to swipe between pages, 2 to swipe between full-screen applications.
      The default is 2.
    '';

    TrackpadThreeFingerVertSwipeGesture = toggleGesture ''
      Whether to enable three-finger vertical swipe gesture (down for Mission Control, up for App Exposé): 0 to disable, 2 to enable.
      The default is 2.
      This setting interacts with `system.defaults.dock.showAppExposeGestureEnabled` and `system.defaults.dock.showMissionControlGestureEnabled` to determine whether vertical swipe gestures are enabled for App Exposé, Mission Control, or both.
    '';

    TrackpadTwoFingerDoubleTapGesture = mkNullableOption types.bool ''
      Whether to enable smart zoom when double-tapping with two fingers.
      The default is false.
    '';

    TrackpadTwoFingerFromRightEdgeSwipeGesture =
      mkNullableOption
        (types.enum [
          0
          3
        ])
        ''
          Whether to enable two-finger swipe-from-right-edge gesture: 0 to disable, 3 to open Notification Center.
          The default is 0.
        '';
  };
}

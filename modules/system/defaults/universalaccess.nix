{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.universalaccess = {
    # UniversalAccessCore's getters use the typed UAPreferences accessors
    # The key constants resolve through libUAPreferences to this domain
    contrast = mkNullableOption (types.numbers.between 0 1) ''
      Enhance display contrast, from zero for normal contrast to one for
      maximum contrast. The native setter accepts values from zero to one
    '';

    hoverTextEnabled = mkNullableOption types.bool ''
      Enable Hover Text to display enlarged text under the pointer while
      holding its activation modifier. Logging out may be needed to apply
      accessibility preference changes
    '';

    hoverTextIsAlwaysOn = mkNullableOption types.bool ''
      Keep Hover Text active without holding its activation modifier.
      Requires Hover Text to be enabled
    '';

    hoverTextFontSize = mkNullableOption types.numbers.positive ''
      Font size in points for Hover Text. Requires Hover Text to be enabled
    '';

    hoverTextHighlightCurrentElement = mkNullableOption types.bool ''
      Highlight the screen element being displayed by Hover Text
    '';

    hoverTextNavigateLinesWithinWindow = mkNullableOption types.bool ''
      Allow navigating between lines within the Hover Text window
    '';

    hoverTypingEnabled = mkNullableOption types.bool ''
      Show an enlarged view of text as it is typed using Hover Typing
    '';

    hoverTypingFontSize = mkNullableOption types.numbers.positive ''
      Font size in points for Hover Typing. Requires Hover Typing to be enabled
    '';

    stickyKeyBeepOnModifier = mkNullableOption types.bool ''
      Play a sound when a modifier key is set using Sticky Keys.
      Requires Sticky Keys to be enabled
    '';

    stickyKeyShowWindow = mkNullableOption types.bool ''
      Display pressed modifier keys on screen while using Sticky Keys
    '';

    slowKeyBeepOn = mkNullableOption types.bool ''
      Play a sound when a key is pressed and accepted while using Slow Keys
    '';

    slowKeyDelay = mkNullableOption types.ints.positive ''
      Delay in milliseconds before a held key is accepted by Slow Keys.
      Requires Slow Keys to be enabled
    '';

    closeViewHotkeysEnabled = mkNullableOption types.bool ''
      Enable keyboard shortcuts for accessibility zoom
    '';

    closeViewTrackpadGestureZoomEnabled = mkNullableOption types.bool ''
      Enable the trackpad gesture for accessibility zoom
    '';

    closeViewSmoothImages = mkNullableOption types.bool ''
      Smooth images while using accessibility zoom
    '';

    closeViewFlashScreenOnNotificationEnabled = mkNullableOption types.bool ''
      Flash the screen when a notification banner appears while zoomed in
    '';

    closeViewTemporaryDetachEnabled = mkNullableOption types.bool ''
      Allow temporarily detaching the zoom view from the pointer using the
      accessibility zoom shortcut
    '';

    closeViewFullscreenPoroEnabled = mkNullableOption types.bool ''
      Allow temporarily toggling full-screen zoom with its keyboard shortcut
    '';

    closeViewShowPreview_v2 = mkNullableOption types.bool ''
      Show a preview rectangle of the zoomed area while zoomed out
    '';

    keyboardAccessEnabled = mkNullableOption types.bool ''
      Enable Full Keyboard Access to navigate controls using the keyboard
    '';

    keyboardAccessFocusRingTimeoutEnabled = mkNullableOption types.bool ''
      Automatically hide the Full Keyboard Access focus indicator after
      inactivity
    '';

    keyboardAccessFocusRingTimeout = mkNullableOption types.numbers.nonnegative ''
      Seconds of inactivity before the Full Keyboard Access focus indicator
      hides. Requires automatic hiding to be enabled
    '';

    keyboardAccessLargeFocusRingEnabled = mkNullableOption types.bool ''
      Increase the size of the Full Keyboard Access focus indicator
    '';

    keyboardAccessFocusRingHighContrastEnabled = mkNullableOption types.bool ''
      Increase the contrast of the Full Keyboard Access focus indicator
    '';

    mouseDriverCursorSize =
      mkNullableOption types.float ''
        Set the size of cursor. 1 for normal, 4 for maximum.
        The default is 1.
      ''
      // {
        example = 1.5;
      };

    reduceMotion = mkNullableOption types.bool ''
      Disable animation when switching screens or opening apps
    '';

    reduceTransparency = mkNullableOption types.bool ''
      Disable transparency in the menu bar and elsewhere.
      The default is false.
    '';

    closeViewScrollWheelToggle = mkNullableOption types.bool ''
      Use scroll gesture with the Ctrl (^) modifier key to zoom.
      The default is false.
    '';

    closeViewZoomFollowsFocus = mkNullableOption types.bool ''
      Follow the keyboard focus while zoomed in.
      Without setting `closeViewScrollWheelToggle` this has no effect.
      The default is false.
    '';
  };
}

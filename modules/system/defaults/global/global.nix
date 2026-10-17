{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  imports = [ ./preferences.nix ];

  options.system.defaults.NSGlobalDomain = {
    # DesktopSettings reads these from the current user's global domain
    # The double-click action is stored as one of the four strings below
    AppleActionOnDoubleClick =
      mkNullableOption
        (types.enum [
          "Minimize"
          "Maximize"
          "Fill"
          "None"
        ])
        ''
          Action when double-clicking a window's title bar. "Maximize" zooms the
          window, "Fill" fills the desktop, "Minimize" minimizes it, and "None"
          disables the action. Available actions depend on the macOS version

          Null leaves the current preference unchanged. Applications may need
          to be reopened before they read the updated preference
        '';

    NSQuitAlwaysKeepsWindows = mkNullableOption types.bool ''
      Restore windows when reopening applications. False corresponds to
      "Close windows when quitting an application" in System Settings.
      Applications may need to be reopened before this takes effect
    '';

    NSCloseAlwaysConfirmsChanges = mkNullableOption types.bool ''
      Ask to keep changes when closing documents with unsaved changes,
      instead of saving them automatically. Applications may need to be
      reopened before this takes effect
    '';

    # KeyboardSettings writes Boolean objects in NSGlobalDomain for these keys
    NSSmartReplyEnabled = mkNullableOption types.bool ''
      Offer Smart Reply suggestions in applications that support them.
      Applications may need to be reopened before this takes effect
    '';

    NSVisualBidiSelectionEnabled = mkNullableOption types.bool ''
      Select bidirectional text in its visual order rather than its logical
      order. Applications may need to be reopened before this takes effect
    '';

    # MouseExtension's acceleration switch stores _UseLinearAccelerationKey
    # MachineSettings resolves that constant to com.apple.mouse.linear
    "com.apple.mouse.linear" = mkNullableOption types.bool ''
      Use linear mouse tracking without pointer acceleration. True disables
      acceleration and false enables it. Logging out may be needed to apply
      the preference
    '';

    AppleShowAllFiles = mkNullableOption types.bool ''
      Whether to always show hidden files. The default is false.
    '';

    AppleEnableMouseSwipeNavigateWithScrolls = mkNullableOption types.bool ''
      Enables swiping left or right with two fingers to navigate backward or forward. The default is true.
    '';

    AppleEnableSwipeNavigateWithScrolls = mkNullableOption types.bool ''
      Enables swiping left or right with two fingers to navigate backward or forward. The default is true.
    '';

    AppleFontSmoothing =
      mkNullableOption
        (types.enum [
          0
          1
          2
        ])
        ''
          Sets the font smoothing level. Rendering behavior depends on the
          macOS version and display
        '';

    AppleInterfaceStyle = mkNullableOption (types.enum [ "Dark" ]) ''
      Set to 'Dark' to enable dark mode.

      To set to light mode, set this to `null` and you'll need to manually run
      {command}`defaults delete -g AppleInterfaceStyle`.

      This option requires logging out and logging back in to apply.
    '';

    AppleIconAppearanceTheme =
      mkNullableOption
        (types.enum [
          "RegularDark"
          "RegularAutomatic"
          "ClearLight"
          "ClearDark"
          "ClearAutomatic"
          "TintedLight"
          "TintedDark"
          "TintedAutomatic"
        ])
        ''
          Set icon and widget style

          To set to default mode, set this to `null` and you'll need to manually run
          {command}`defaults delete -g AppleIconAppearanceTheme`.

          This option requires logging out and logging back in to apply.
        '';

    AppleInterfaceStyleSwitchesAutomatically = mkNullableOption types.bool ''
      Whether to automatically switch between light and dark mode. The default is false.
    '';

    AppleKeyboardUIMode =
      mkNullableOption
        (types.enum [
          0
          2
          3
        ])
        ''
          Configures the keyboard control behavior. The default is 0.

          0 = Disabled
          2 = Enabled on Sonoma or later
          3 = Enabled on older macOS versions
        '';

    ApplePressAndHoldEnabled = mkNullableOption types.bool ''
      Whether to enable the press-and-hold feature. The default is true.
    '';

    AppleShowAllExtensions = mkNullableOption types.bool ''
      Whether to show all file extensions in Finder. The default is false.
    '';

    AppleShowScrollBars =
      mkNullableOption
        (types.enum [
          "WhenScrolling"
          "Automatic"
          "Always"
        ])
        ''
          When to show the scrollbars. Options are 'WhenScrolling', 'Automatic' and 'Always'.
        '';

    AppleScrollerPagingBehavior = mkNullableOption types.bool ''
      Jump to the spot that's clicked on the scroll bar. The default is false.
    '';

    AppleSpacesSwitchOnActivate = mkNullableOption types.bool ''
      Whether or not to switch to a workspace that has a window of the application open, that is switched to. The default is true.
    '';

    NSAutomaticCapitalizationEnabled = mkNullableOption types.bool ''
      Whether to enable automatic capitalization. The default is true.
    '';

    NSAutomaticInlinePredictionEnabled = mkNullableOption types.bool ''
      Whether to enable inline predictive text. The default is true.
    '';

    NSAutomaticDashSubstitutionEnabled = mkNullableOption types.bool ''
      Whether to enable smart dash substitution. The default is true.
    '';

    NSAutomaticPeriodSubstitutionEnabled = mkNullableOption types.bool ''
      Whether to enable smart period substitution. The default is true.
    '';

    NSAutomaticQuoteSubstitutionEnabled = mkNullableOption types.bool ''
      Whether to enable smart quote substitution. The default is true.
    '';

    NSAutomaticSpellingCorrectionEnabled = mkNullableOption types.bool ''
      Whether to enable automatic spelling correction. The default is true.
    '';

    NSAutomaticWindowAnimationsEnabled = mkNullableOption types.bool ''
      Whether to animate opening and closing of windows and popovers. The default is true.
    '';

    NSDisableAutomaticTermination = mkNullableOption types.bool ''
      Whether to disable the automatic termination of inactive apps.
    '';

    NSDocumentSaveNewDocumentsToCloud = mkNullableOption types.bool ''
      Whether to save new documents to iCloud by default. The default is true.
    '';

    AppleWindowTabbingMode =
      mkNullableOption
        (types.enum [
          "manual"
          "always"
          "fullscreen"
        ])
        ''
          Sets the window tabbing when opening a new document: 'manual', 'always', or 'fullscreen'. The default is 'fullscreen'.
        '';

    NSNavPanelExpandedStateForSaveMode = mkNullableOption types.bool ''
      Whether to use expanded save panel by default. The default is false.
    '';

    NSNavPanelExpandedStateForSaveMode2 = mkNullableOption types.bool ''
      Whether to use expanded save panel by default. The default is false.
    '';

    NSTableViewDefaultSizeMode =
      mkNullableOption
        (types.enum [
          1
          2
          3
        ])
        ''
          Sets the size of the finder sidebar icons: 1 (small), 2 (medium) or 3 (large). The default is 3.
        '';

    NSTextShowsControlCharacters = mkNullableOption types.bool ''
      Whether to display ASCII control characters using caret notation in standard text views. The default is false.
    '';

    NSUseAnimatedFocusRing = mkNullableOption types.bool ''
      Whether to enable the focus ring animation. The default is true.
    '';

    NSScrollAnimationEnabled = mkNullableOption types.bool ''
      Whether to enable smooth scrolling. The default is true.
    '';

    NSWindowResizeTime =
      mkNullableOption types.float ''
        Sets the speed speed of window resizing. The default is given in the example.
      ''
      // {
        example = 0.20;
      };

    NSWindowShouldDragOnGesture = mkNullableOption types.bool ''
      Whether to enable moving window by holding anywhere on it like on Linux. The default is false.
    '';

    NSStatusItemSpacing =
      mkNullableOption types.int ''
        Sets the spacing between status icons in the menu bar.
      ''
      // {
        example = 12;
      };

    NSStatusItemSelectionPadding =
      mkNullableOption types.int ''
        Sets the padding around status icons in the menu bar.
      ''
      // {
        example = 6;
      };

    InitialKeyRepeat = mkNullableOption types.int ''
      Apple menu > System Preferences > Keyboard

      If you press and hold certain keyboard keys when in a text area, the key’s character begins to repeat.
      For example, the Delete key continues to remove text for as long as you hold it down.

      This sets how long you must hold down the key before it starts repeating.
    '';

    KeyRepeat = mkNullableOption types.int ''
      Apple menu > System Preferences > Keyboard

      If you press and hold certain keyboard keys when in a text area, the key’s character begins to repeat.
      For example, the Delete key continues to remove text for as long as you hold it down.

      This sets how fast it repeats once it starts.
    '';

    PMPrintingExpandedStateForPrint = mkNullableOption types.bool ''
      Whether to use the expanded print panel by default. The default is false.
    '';

    PMPrintingExpandedStateForPrint2 = mkNullableOption types.bool ''
      Whether to use the expanded print panel by default. The default is false.
    '';

    "com.apple.keyboard.fnState" = mkNullableOption types.bool ''
      Use F1, F2, etc. keys as standard function keys.
    '';

    "com.apple.mouse.tapBehavior" = mkNullableOption (types.enum [ 1 ]) ''
      Configures the trackpad tap behavior. Mode 1 enables tap to click.
    '';

    "com.apple.sound.beep.volume" = mkNullableOption types.float ''
      Apple menu > System Preferences > Sound

      Sets the beep/alert volume level from 0.000 (muted) to 1.000 (100% volume).

      75% = 0.7788008

      50% = 0.6065307

      25% = 0.4723665
    '';

    "com.apple.sound.beep.feedback" = mkNullableOption types.int ''
      Apple menu > System Preferences > Sound

      Make a feedback sound when the system volume changed. This setting accepts
      the integers 0 or 1. Defaults to 1.
    '';

    "com.apple.trackpad.enableSecondaryClick" = mkNullableOption types.bool ''
      Whether to enable trackpad secondary click. The default is true.
    '';

    "com.apple.trackpad.trackpadCornerClickBehavior" = mkNullableOption (types.enum [ 1 ]) ''
      Configures the trackpad corner click behavior. Mode 1 enables right click.
    '';

    "com.apple.trackpad.scaling" = mkNullableOption types.float ''
      Configures the trackpad tracking speed (0 to 3). The default is "1".
    '';

    "com.apple.trackpad.forceClick" = mkNullableOption types.bool ''
      Whether to enable trackpad force click.
    '';

    "com.apple.springing.enabled" = mkNullableOption types.bool ''
      Whether to enable spring loading (expose) for directories.
    '';

    "com.apple.springing.delay" =
      mkNullableOption types.float ''
        Set the spring loading delay for directories. The default is given in the example.
      ''
      // {
        example = 1.0;
      };

    "com.apple.swipescrolldirection" = mkNullableOption types.bool ''
      Whether to enable "Natural" scrolling direction. The default is true.
    '';

    AppleMeasurementUnits =
      mkNullableOption
        (types.enum [
          "Centimeters"
          "Inches"
        ])
        ''
          Whether to use centimeters (metric) or inches (US, UK) as the measurement unit. The default is based on region settings.
        '';

    AppleMetricUnits =
      mkNullableOption
        (types.enum [
          0
          1
        ])
        ''
          Whether to use the metric system. The default is based on region settings.
        '';

    AppleTemperatureUnit =
      mkNullableOption
        (types.enum [
          "Celsius"
          "Fahrenheit"
        ])
        ''
          Whether to use Celsius or Fahrenheit. The default is based on region settings.
        '';

    AppleICUForce24HourTime = mkNullableOption types.bool ''
      Whether to use 24-hour or 12-hour time. The default is based on region settings.
    '';

    _HIHideMenuBar = mkNullableOption types.bool ''
      Whether to autohide the menu bar. The default is false.
    '';

    AppleReduceDesktopTinting = mkNullableOption types.bool ''
      Reduce wallpaper tinting in window backgrounds. True reduces tinting
      and false allows the wallpaper color to tint window backgrounds
    '';
  };

}

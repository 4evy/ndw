{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Appearance" "com.apple.settings.appearance";
  inherit (page) setting select toggle;

  inherit (settingsLib)
    numberBetween
    global
    stored
    absent
    bool
    inverted
    enum
    notifies
    live
    allowedWhen
    onlyWhen
    ;

  option = name: "applications.systemSettings.appearance.${name}";

  colorsChanged = notifies [
    "AppleColorPreferencesChangedNotification"
    "AppleAquaColorVariantChanged"
  ];

  selected = {
    selected = true;
  };
in
{
  appearance = setting {
    ui = "Appearance";
    storage = {
      style = global "AppleInterfaceStyle";
      automatic = global "AppleInterfaceStyleSwitchesAutomatically";
    };
    value = enum {
      Light = {
        style = absent;
        automatic = absent;
      };
      Dark = {
        style = "Dark";
        automatic = absent;
      };
      Auto = {
        automatic = true;
      };
    };
    apply =
      value:
      if value == "Auto" then
        live.appearance { automatic = true; }
      else
        live.appearance {
          automatic = false;
          dark = value == "Dark";
        };
    canUnset = true;
    verify.expect = {
      Light = {
        "AXButton:Light" = selected;
      };
      Dark = {
        "AXButton:Dark" = selected;
      };
      Auto = {
        "AXButton:Auto" = selected;
      };
    };
  };

  liquidGlass = setting {
    ui = "Liquid Glass";
    description = "How tinted Liquid Glass is, from 0 (clear) to 1 (tinted). System Settings defaults to 0.5.";
    storage = stored "float" (global "NSGlassTintAmount");
    value = numberBetween 0.0 1.0;
    verify.expect = {
      "0" = {
        "Liquid Glass Tint Amount" = 0;
      };
      "0.5" = {
        "Liquid Glass Tint Amount" = 0.5;
      };
      "1" = {
        "Liquid Glass Tint Amount" = 1;
      };
    };
  };

  accentColor = select {
    ui = [
      "Theme"
      "Color"
    ];
    storage = {
      color = global "AppleAccentColor";
      variant = global "AppleAquaColorVariant";
    };
    value = enum {
      Multicolor = {
        color = absent;
        variant = 1;
      };
      Graphite = {
        color = -1;
        variant = 6;
      };
      Red = {
        color = 0;
        variant = 1;
      };
      Orange = {
        color = 1;
        variant = 1;
      };
      Yellow = {
        color = 2;
        variant = 1;
      };
      Green = {
        color = 3;
        variant = 1;
      };
      Blue = {
        color = 4;
        variant = 1;
      };
      Purple = {
        color = 5;
        variant = 1;
      };
      Pink = {
        color = 6;
        variant = 1;
      };
    };
    behaviors = [ colorsChanged ];
    control = "AXStaticText:Color";
    choices = [
      "Blue"
      "Multicolor"
      "Graphite"
    ];
  };

  textHighlightColor = select {
    ui = [
      "Theme"
      "Text highlight color"
    ];
    description = "The color of selected text. Automatic follows the accent color.";
    storage = global "AppleHighlightColor";
    value = enum {
      Automatic = absent;
      Blue = "0.698039 0.843137 1.000000 Blue";
      Purple = "0.968627 0.831373 1.000000 Purple";
      Pink = "1.000000 0.749020 0.823529 Pink";
      Red = "1.000000 0.733333 0.721569 Red";
      Orange = "1.000000 0.874510 0.701961 Orange";
      Yellow = "1.000000 0.937255 0.690196 Yellow";
      Green = "0.752941 0.964706 0.678431 Green";
      Graphite = "0.847059 0.847059 0.862745 Graphite";
    };
    behaviors = [ colorsChanged ];
    relations = [
      (allowedWhen "Automatic" (option "accentColor") (
        color: color == "Multicolor"
      ) "System Settings only offers Automatic with the Multicolor accent color")
    ];
    control = "HighlightColorPicker";
    choices = [
      "Purple"
      "Blue"
    ];
  };

  iconAndWidgetStyle = setting {
    ui = [
      "Theme"
      "Icon & widget style"
    ];
    description = "The icon and widget style, and whether it's light, dark or automatic. \"unset\" is Default in Light.";
    storage = global "AppleIconAppearanceTheme";
    value = enum {
      RegularDark = "RegularDark";
      RegularAutomatic = "RegularAutomatic";
      ClearLight = "ClearLight";
      ClearDark = "ClearDark";
      ClearAutomatic = "ClearAutomatic";
      TintedLight = "TintedLight";
      TintedDark = "TintedDark";
      TintedAutomatic = "TintedAutomatic";
    };
    verify.expect = {
      ClearDark = {
        "Clear + Icon & widget style" = selected;
        "AXRadioButton:Dark" = 1;
      };
      # The Default style shows as Dark in dark or automatic appearance
      RegularAutomatic = {
        "Dark + Icon & widget style" = selected;
        "AXRadioButton:Auto" = 1;
      };
      TintedLight = {
        "Tinted + Icon & widget style" = selected;
        "AXRadioButton:Light" = 1;
      };
    };
  };

  iconWidgetAndFolderColor = select {
    ui = [
      "Theme"
      "Icon, widget & folder color"
    ];
    storage = global "AppleIconAppearanceTintColor";
    value = enum {
      Automatic = absent;
      Red = "Red";
      Orange = "Orange";
      Yellow = "Yellow";
      Green = "Green";
      Blue = "Blue";
      Purple = "Purple";
      Pink = "Pink";
      Graphite = "Graphite";
    };
    relations = [
      (onlyWhen (option "iconAndWidgetStyle") (
        style:
        lib.any (prefix: lib.hasPrefix prefix style) [
          "Clear"
          "Tinted"
        ]
      ) "only the Clear and Tinted styles use it")
    ];
    control = "Icon, widget & Folder color";
    choices = [
      "Red"
      "Graphite"
    ];
  };

  sidebarIconSize = select {
    ui = [
      "Windows"
      "Sidebar icon size"
    ];
    storage = global "NSTableViewDefaultSizeMode";
    value = enum {
      Small = 1;
      Medium = 2;
      Large = 3;
    };
    control = "SidebarIconSizePicker";
  };

  allowWallpaperTintingInWindows = toggle {
    ui = [
      "Windows"
      "Tint window background with wallpaper color"
    ];
    storage = global "AppleReduceDesktopTinting";
    value = inverted bool;
    control = "TintWindowBackgroundToggle";
    click = true;
  };

  showScrollBars = page.radio {
    ui = [
      "Windows"
      "Show scroll bars"
    ];
    storage = global "AppleShowScrollBars";
    value = enum {
      "Automatically based on mouse or trackpad" = "Automatic";
      "When scrolling" = "WhenScrolling";
      "Always" = "Always";
    };
  };

  clickInTheScrollBarTo = setting {
    ui = [
      "Windows"
      "Click in the scroll bar to"
    ];
    storage = global "AppleScrollerPagingBehavior";
    value = enum {
      "Jump to the next page" = false;
      "Jump to the spot that's clicked" = true;
    };
    verify = {
      operate = [
        [
          "press"
          "AXRadioButton:Jump to the spot that’s clicked"
        ]
        [
          "press"
          "AXRadioButton:Jump to the next page"
        ]
      ];
      expect = {
        "Jump to the next page" = {
          "AXRadioButton:Jump to the next page" = 1;
        };
        "Jump to the spot that's clicked" = {
          "AXRadioButton:Jump to the spot that’s clicked" = 1;
        };
      };
    };
  };
}

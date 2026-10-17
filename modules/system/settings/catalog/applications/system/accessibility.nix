{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Accessibility" "com.apple.settings.accessibility";
  inherit (page) setting toggle preference;

  inherit (settingsLib)
    boolKeys
    integerBool
    inverted
    bool
    eachKey
    boolAs
    numberBetween
    restarts
    user
    global
    enum
    enumDict
    rgb
    inDict
    absent
    text
    number
    snapshot
    byHost
    flagsWhenAbsent
    dictSwitches
    activatesShortcuts
    allowedWhen
    conflictsWith
    ops
    ;

  displaySettings = page.navigate "Display" "AX_FEATURE_DISPLAY";
  spokenSettings = page.section { ui = "Read & Speak"; };
  hoverTextSettings = page.section {
    ui = [
      "Hover Text"
      "Hover Text (i)"
    ];
  };
  zoomAdvancedSettings =
    page.navigate
      [
        "Zoom"
        "Advanced…"
      ]
      [
        "AX_FEATURE_ZOOM"
        "Advanced…"
      ];
  accessibilityKeyboardSettings = page.navigate [
    "Keyboard"
    "Accessibility Keyboard (i)"
  ] keyboardSheet;
  headPointerSettings = page.section {
    ui = [
      "Pointer Control"
      "Head Pointer (i)"
    ];
  };
  liveCaptionsSettings = page.section { ui = "Live Captions"; };
  switchControlSettings = page.navigate "Switch Control" switchControlPage;
  switchTimingSettings = switchControlSettings.navigate "Switch Timing…" (
    switchControlPage ++ [ "Switch Timing…" ]
  );
  navigationTimingSettings = switchControlSettings.navigate "Navigation Timing…" (
    switchControlPage ++ [ "Navigation Timing…" ]
  );

  pageIds = {
    Display = "AX_FEATURE_DISPLAY";
    Motion = "AX_FEATURE_MOTION";
    Audio = "AX_FEATURE_AUDIO";
    "Subtitles and Captioning" = "AX_FEATURE_CAPTIONS";
    Keyboard = "AX_FEATURE_KEYBOARD";
    "Pointer Control" = "AX_FEATURE_POINTERCONTROL";
    "Live Captions" = "AX_FEATURE_SYSTEMTRANSCRIPTION";
    "Live Speech" = "AX_FEATURE_LIVESPEECH";
    "Switch Control" = "AX_FEATURE_SWITCHCONTROL";
    VoiceOver = "AX_FEATURE_VOICEOVER";
    RTT = "AX_FEATURE_RTT";
  };

  feature =
    page: ui: key: control:
    switch {
      inherit page ui control;
      storage = universalAccess key;
    };

  fontCodec =
    baseSize:
    text
    // {
      examples = [
        "Default"
        "Helvetica"
      ];
      encode =
        keys: font:
        if font == "Default" then
          [ (ops.delete keys.font) ] ++ lib.optional (keys ? style) (ops.write keys.style 1)
        else
          [
            (ops.write keys.font {
              fontName = font;
              fontSize = baseSize;
            })
          ]
          ++ lib.optional (keys ? style) (ops.write keys.style 2);
      decode =
        keys: get:
        let
          stored = get keys.font;
        in
        if stored == null then "Default" else stored.fontName or null;
    };

  rgba = {
    kind = "color";
    type = lib.types.either (lib.types.enum [ "Default" ]) (
      lib.types.submodule {
        options =
          lib.genAttrs [ "red" "green" "blue" ] (_: lib.mkOption { type = lib.types.numbers.between 0 1; })
          // {
            alpha = lib.mkOption {
              type = lib.types.numbers.between 0 1;
              default = 1.0;
            };
          };
      }
    );
    choices = [ "Default" ];
    examples = [
      "Default"
      {
        red = 1.0;
        green = 0.0;
        blue = 0.0;
        alpha = 1.0;
      }
    ];
    encode =
      keys: color:
      if color == "Default" then
        [ (ops.delete keys.value) ]
      else
        [
          (ops.write keys.value {
            red = color.red * 1.0;
            green = color.green * 1.0;
            blue = color.blue * 1.0;
            alpha = (color.alpha or 1.0) * 1.0;
          })
        ];
    fromName = name: if name == "Default" then name else builtins.fromJSON name;
  };

  # Picking either color marks the pointer as customized
  cursorColor = rgba // {
    encode =
      keys: color:
      rgba.encode keys color
      ++ lib.optional (color != "Default") (ops.write (universalAccess "cursorIsCustomized") true);
  };

  modifierMask = {
    control = 262144;
    option = 524288;
    shift = 131072;
    command = 1048576;
  };

  sheetPath = sheet: sheet.open or "${sheet.ui} (i)";

  accessibility = user "com.apple.Accessibility";
  universalAccess = user "com.apple.universalaccess";
  mediaAccessibility = user "com.apple.mediaaccessibility";
  comfortSounds = user "com.apple.ComfortSounds";

  switch =
    {
      page,
      ui,
      storage,
      value ? bool,
      control ? ui,
      behaviors ? [ ],
      sideEffects ? null,
    }:
    toggle {
      inherit storage value behaviors;
      ui = [
        page
        ui
      ];
      control = "AXCheckBox:${control}";
      verify = {
        inherit sideEffects;
        open = [ pageIds.${page} ];
      };
    };

  both =
    {
      page,
      ui,
      accessibilityKey,
      universalAccessKey,
    }:
    switch {
      inherit page ui;
      storage = {
        new = accessibility accessibilityKey;
        old = universalAccess universalAccessKey;
      };
      value = boolKeys {
        new = integerBool;
        old = bool;
      };
    };

  axSwitch =
    {
      page,
      ui,
      key,
    }:
    switch {
      inherit page ui;
      storage = accessibility key;
      value = integerBool;
    };

  onPage =
    page: ui: args:
    args // { inherit page ui; };
  display = onPage "Display";
  motion = onPage "Motion";
  audio = onPage "Audio";
  captions = onPage "Subtitles and Captioning";

  speech = user "com.apple.speech.synthesis.general.prefs";

  spokenCheckbox = settingsLib.checkbox spoken;
  spoken = pageControl "Read & Speak" "AX_FEATURE_SPOKENCONTENT";

  speakSelectionSheet = {
    ui = "Speak selection";
    id = "AX_SPOKEN_HOTKEY";
  };
  pointerSheet = {
    ui = "Speak item under the pointer";
    id = "AX_SPOKEN_POINTER_ELEMENT";
  };

  highlightColors = enum {
    Default = 0;
    Blue = 1;
    Yellow = 2;
    Green = 3;
  };

  colors = enumDict {
    Default = absent;
    Black = rgb 0.0 0.0 0.0;
    Blue = rgb 0.0 0.0 1.0;
    Cyan = rgb 0.0 1.0 1.0;
    Green = rgb 0.0 1.0 0.0;
    Magenta = rgb 1.0 0.0 1.0;
    Red = rgb 1.0 0.0 0.0;
    White = rgb 1.0 1.0 1.0;
    Yellow = rgb 1.0 1.0 0.0;
  };

  hoverCheckbox = settingsLib.checkbox hover;
  hover = pageControl "Hover Text" "AX_FEATURE_HOVERTEXT";

  hoverColor =
    sheet: ui: key: control:
    hover {
      inherit ui sheet control;
      storage = universalAccess key;
      value = colors;
      expect = {
        Default = "Default";
        Yellow = "Yellow";
      };
    };

  hoverTextSheet = {
    ui = "Hover Text";
    id = "AX_HOVER_TEXT_ENABLE";
  };
  hoverTypingSheet = {
    ui = "Hover Typing";
    id = "AX_HOVER_TYPING_ENABLE";
  };

  control =
    {
      page,
      pageId,
      sheet ? null,
      value ? bool,
      expect ? {
        true = 1;
        false = 0;
      },
      ...
    }@args:
    (pageSettings page pageId sheet).control (
      removeAttrs args [
        "page"
        "pageId"
        "sheet"
        "verify"
      ]
      // {
        inherit value expect;
      }
    );

  pageSettings =
    pageName: pageId: sheet:
    page.navigate ([ pageName ] ++ lib.optional (sheet != null) (sheetPath sheet)) (
      [ pageId ] ++ lib.optional (sheet != null) (sheet.open or "${sheet.id}.infoButton")
    );

  pageControl =
    page: pageId: args:
    control (args // { inherit page pageId; });

  keyboardSheet = [
    "AX_FEATURE_KEYBOARD"
    "AX_VIRTUAL_KEYBOARD.infoButton"
  ];
  switchControlPage = [ "AX_FEATURE_SWITCHCONTROL" ];

  # For settings whose switch shows the running feature rather than the key,
  # so System Settings can't confirm them
  unverified = setting: setting // { verify = null; };

  zoomCheckbox = settingsLib.checkbox zoom;
  zoom = pageControl "Zoom" "AX_FEATURE_ZOOM";
  keyboard = pageControl "Keyboard" "AX_FEATURE_KEYBOARD";
  pointerCheckbox = settingsLib.checkbox pointer;
  pointer = pageControl "Pointer Control" "AX_FEATURE_POINTERCONTROL";

  trackpad = name: {
    builtIn = user "com.apple.AppleMultitouchTrackpad" name;
    bluetooth = user "com.apple.driver.AppleBluetoothMultitouch.trackpad" name;
  };

  # SpeakSelection stores "no override" as this string
  systemLanguage = text // {
    examples = [
      "Use System Language"
      "en"
    ];
    encode =
      keys: language:
      text.encode keys (
        if language == "Use System Language" then "__com.apple.AXSettingRecord.nilSentinel__" else language
      );
    decode =
      keys: get:
      let
        language = text.decode keys get;
      in
      if language == "__com.apple.AXSettingRecord.nilSentinel__" then "Use System Language" else language;
  };
in
{
  display = {
    invertColors = switch (
      display "Invert colors" {
        storage = {
          polarity = user "com.apple.CoreGraphics" "DisplayUseInvertedPolarity";
          whiteOnBlack = universalAccess "whiteOnBlack";
          enabled = accessibility "InvertColorsEnabled";
          filter = mediaAccessibility "__Inverted__-MADisplayFilterCategoryEnabled";
        };
        value = boolKeys {
          polarity = bool;
          whiteOnBlack = bool;
          enabled = integerBool;
          filter = integerBool;
        };
        control = "AX_INVERT_COLOR";
      }
    );

    invertColorsMode = displaySettings.setting {
      ui = [
        "Invert colors"
        "Smart / Classic"
      ];
      storage = {
        classic = universalAccess "classicInvertColor";
        preference = accessibility "AXSClassicInvertColorsPreference";
      };
      value = enum {
        Smart = {
          classic = false;
          preference = 0;
        };
        Classic = {
          classic = true;
          preference = 1;
        };
      };
    };

    increaseContrast = both (
      display "Increase contrast" {
        accessibilityKey = "DarkenSystemColors";
        universalAccessKey = "increaseContrast";
      }
    );

    reduceTransparency = both (
      display "Reduce transparency" {
        accessibilityKey = "EnhancedBackgroundContrastEnabled";
        universalAccessKey = "reduceTransparency";
      }
    );

    showBorders = axSwitch (display "Show borders" { key = "ButtonShapesEnabled"; });

    differentiateWithoutColor = both (
      display "Differentiate without color" {
        accessibilityKey = "DifferentiateWithoutColor";
        universalAccessKey = "differentiateWithoutColor";
      }
    );

    dimFlashingLights = axSwitch (display "Dim flashing lights" { key = "PhotosensitiveMitigation"; });

    showWindowTitleIcons = switch (
      display "Show window title icons" {
        storage = universalAccess "showWindowTitlebarIcons";
      }
    );

    menuBarSize = displaySettings.radio {
      ui = "Menu bar size";
      storage = global "AppleMenuBarFontSize";
      value = enum {
        Default = absent;
        Large = "large";
      };
    };

    textSize =
      let
        sizes = [
          "XXXS"
          "XXS"
          "XS"
          "S"
          "DEFAULT"
          "M"
          "L"
          "XL"
          "XXL"
          "XXXL"
          "AX1"
          "AX2"
          "AX3"
          "AX4"
        ];
        sizeFor = size: if size == "Use Preferred Reading Size" then "UseGlobal" else size;
      in
      {
        preferredReadingSize = displaySettings.setting {
          ui = [
            "Text size"
            "Preferred reading size"
          ];
          storage = universalAccess "FontSizeCategory";
          value = inDict "global" (enum (lib.genAttrs sizes (size: size)));
          # unset would reset every app's size too
          canUnset = false;
        };

        apps = displaySettings.setting {
          ui = "Text size";
          description = "A size per app by bundle identifier, or \"Use Preferred Reading Size\".";
          storage = universalAccess "FontSizeCategory";
          value = {
            kind = "apps";
            type = lib.types.attrsOf (lib.types.enum ([ "Use Preferred Reading Size" ] ++ sizes));
            choices = [ "Use Preferred Reading Size" ] ++ sizes;
            examples = [ { "com.apple.mail" = "XL"; } ];
            encode =
              keys: apps: lib.optional (apps != { }) (ops.mergeDict keys.value (lib.mapAttrs (_: sizeFor) apps));
            fromName = builtins.fromJSON;
          };
          canUnset = false;
        };
      };

    displayContrast = displaySettings.control {
      ui = "Display contrast";
      storage = universalAccess "contrast";
      value = numberBetween 0.0 1.0;
      control = "AXSlider:AX_ENHANCE_CONTRAST";
      expect = {
        "0.0" = 0.0;
        "0.5" = 0.5;
      };
    };

    pointerSize = displaySettings.control {
      ui = "Pointer size";
      storage = universalAccess "mouseDriverCursorSize";
      value = numberBetween 1.0 4.0;
      control = "AXSlider:AX_CURSOR_SIZE";
      expect = {
        "1.0" = 1.0;
        "2.0" = 2.0;
      };
    };

    pointerOutlineColor =
      displaySettings.preference "Pointer outline color" (universalAccess "cursorOutline")
        cursorColor;

    pointerFillColor =
      displaySettings.preference "Pointer fill color" (universalAccess "cursorFill")
        cursorColor;

    preferHorizontalText = axSwitch (
      display "Prefer horizontal text" { key = "PrefersHorizontalText"; }
    );

    shakeMousePointerToLocate = switch (
      display "Shake mouse pointer to locate" {
        storage = global "CGDisableCursorLocationMagnification";
        value = inverted bool;
      }
    );

    colorFilters = switch (
      display "Color filters" {
        storage = mediaAccessibility "__Color__-MADisplayFilterCategoryEnabled";
        value = integerBool;
      }
    );

    filterIntensity =
      lib.mapAttrs
        (
          _: filter:
          displaySettings.setting {
            ui = [
              "Filter type: ${filter.type}"
              "Intensity"
            ];
            description = "0 to 1.";
            storage = mediaAccessibility filter.key;
            value = numberBetween 0.0 1.0;
          }
        )
        {
          grayscale = {
            type = "Grayscale";
            key = "MADisplayFilterGrayscaleCorrectionIntensity";
          };
          redGreen = {
            type = "Red/Green filter (Protanopia)";
            key = "MADisplayFilterRedColorCorrectionIntensity";
          };
          greenRed = {
            type = "Green/Red filter (Deuteranopia)";
            key = "MADisplayFilterGreenColorCorrectionIntensity";
          };
          blueYellow = {
            type = "Blue/Yellow filter (Tritanopia)";
            key = "MADisplayFilterBlueColorCorrectionIntensity";
          };
          colorTint = {
            type = "Color Tint";
            key = "MADisplayFilterSingleColorIntensity";
          };
        };

    tintHue = displaySettings.preference [
      "Filter type: Color Tint"
      "Tint"
    ] (mediaAccessibility "MADisplayFilterSingleColorHue") (numberBetween 0.0 1.0);

    filterType = displaySettings.select {
      ui = "Filter type";
      storage = mediaAccessibility "__Color__-MADisplayFilterType";
      value = enum {
        Grayscale = 1;
        "Red/Green filter (Protanopia)" = 2;
        "Green/Red filter (Deuteranopia)" = 4;
        "Blue/Yellow filter (Tritanopia)" = 8;
        "Color Tint" = 16;
      };
      choices = [
        "Grayscale"
        "Color Tint"
      ];
    };
  };

  motion = {
    reduceMotion = both (
      motion "Reduce motion" {
        accessibilityKey = "ReduceMotionEnabled";
        universalAccessKey = "reduceMotion";
      }
    );

    autoPlayAnimatedImages = axSwitch (
      motion "Auto-play animated images" {
        key = "ReduceMotionAutoplayAnimatedImagesEnabled";
      }
    );

    preferNonBlinkingCursor = axSwitch (
      motion "Prefer non-blinking cursor" {
        key = "PrefersNonBlinkingCursorIndicator";
      }
    );

    vehicleMotionCues = axSwitch (motion "Vehicle Motion Cues" { key = "AXSMotionCuesEnabled"; });
  };

  audio = {
    flashTheScreenWhenAnAlertSoundOccurs = switch (
      audio "Flash the screen when an alert sound occurs" {
        storage = {
          global = global "com.apple.sound.beep.flash";
          old = universalAccess "flashScreen";
        };
        value = boolKeys {
          global = integerBool;
          old = bool;
        };
      }
    );

    playStereoAudioAsMono = unverified (
      switch (
        audio "Play stereo audio as mono" {
          storage = universalAccess "stereoAsMono";
        }
      )
    );

    backgroundSounds = switch (
      audio "Background sounds" {
        storage = user "com.apple.ComfortSounds" "comfortSoundsEnabled";
      }
    );

    turnOffBackgroundSoundsWhenYourMacIsNotInUse = switch (
      audio "Turn off background sounds when your Mac is not in use" {
        storage = user "com.apple.ComfortSounds" "stopsOnLock";
      }
    );

    backgroundSound = setting {
      ui = [
        "Audio"
        "Background sounds"
        "Choose…"
      ];
      storage.sound = comfortSounds "ComfortSoundsSelectedSound";
      value = snapshot;
    };

    backgroundSoundsVolume = preference [
      "Audio"
      "Background sounds"
      "Volume"
    ] (comfortSounds "relativeVolume") (numberBetween 0.0 1.0);

    backgroundSoundsOptions =
      let
        choose =
          ui: key: control:
          toggle {
            inherit ui;
            storage = comfortSounds key;
            control = "AXCheckBox:${control}";
            verify.open = [
              "AX_FEATURE_AUDIO"
              "Choose…"
            ];
          };
      in
      {
        equalizer = unverified (
          choose [
            "Audio"
            "Background sounds"
            "Choose…"
            "Equalizer"
          ] "tinnitusFilterEnabled" "AX_BACKGROUND_SOUNDS_FILTER"
        );

        balance = preference [
          "Audio"
          "Background sounds"
          "Choose…"
          "Balance"
        ] (comfortSounds "tinnitusBalance") (numberBetween (-1.0) 1.0);

        timer = unverified (
          choose [
            "Audio"
            "Background sounds"
            "Choose…"
            "Timer"
          ] "timerEnabled" "AX_BACKGROUND_SOUNDS_TIMER_TOGGLE"
        );

        setTimer = setting {
          ui = [
            "Audio"
            "Background sounds"
            "Choose…"
            "Set Timer"
          ];
          storage = comfortSounds "timerOption";
          value = enum {
            "At a specific time" = 0;
            "After an amount of time" = 1;
          };
        };
      };
  };

  subtitlesAndCaptioning = {
    preferClosedCaptionsAndSdh = switch (
      captions "Prefer closed captions and SDH" {
        storage = mediaAccessibility "MACaptionPreferAccessibleCaptions";
      }
    );

    showAutomaticallyWhenLanguagesDoNotMatch = axSwitch (
      captions "Show automatically when languages do not match" {
        key = "AXSAutomaticCaptionsShowWhenLanguageMismatch";
      }
    );

    showWhenMuted = axSwitch (
      captions "Show when muted" { key = "AXSAutomaticSubtitlesShowWhenMuted"; }
    );

    showOnSkipBack = axSwitch (
      captions "Show on skip back" { key = "AXSAutomaticSubtitlesShowOnSkipBack"; }
    );

    applyAcrossApps = switch (
      captions "Apply across apps" {
        storage = mediaAccessibility "MACaptionDisplayTypeStorage";
        value = boolAs 0 1;
        control = "AX_CAPTIONING_DISPLAY_TYPE_STORAGE";
      }
    );
  };

  readAndSpeak = {
    speakSelection = spoken {
      ui = "Speak selection";
      storage = {
        enabled = universalAccess "speakSelectionEnabled";
        hotKey = speech "SpokenUIUseSpeakingHotKeyFlag";
      };
      value = eachKey bool;
      control = "AXCheckBox:AX_SPOKEN_HOTKEY";
    };

    speakItemUnderThePointer =
      spokenCheckbox "Speak item under the pointer" (universalAccess "speakItemUnderMouseEnabled")
        "AXCheckBox:AX_SPOKEN_POINTER_ELEMENT";

    speakAnnouncements =
      spokenCheckbox "Speak announcements" (speech "TalkingAlertsSpeakTextFlag")
        "AXCheckBox:AX_SPOKEN_ALERTS";

    speakTypingFeedback =
      spokenCheckbox "Speak typing feedback" (universalAccess "typingEchoEnabled")
        "AXCheckBox:AX_SPOKEN_TYPING_ECHO";

    systemSpeechLanguage = spokenSettings.setting {
      ui = "System speech language";
      description = "\"Use System Language\", or a language code such as \"en\" or \"nl\".";
      storage = user "com.apple.SpeakSelection" "TTSSettingsSystemLanguageOverride";
      value = systemLanguage;
    };

    detectLanguages =
      spokenCheckbox "Detect languages" (universalAccess "detectLanguagesEnabled")
        "AXCheckBox:AX_SPOKEN_DETECT_LANGUAGES";

    pronunciations =
      spokenCheckbox "Pronunciations" (universalAccess "pronunciationsEnabledKey")
        "AXCheckBox:AX_SPOKEN_PRONUNCIATIONS";

    accessibilityReader.enable =
      spokenCheckbox "Accessibility Reader" (universalAccess "AccessibilityReaderHotkeyEnabled")
        "AXCheckBox:AX_READER_HOTKEY_ENABLED";

    accessibilityReader.autoplay = spoken {
      ui = "Autoplay in Accessibility Reader";
      sheet = {
        ui = "Accessibility Reader";
        id = "AX_READER_HOTKEY_ENABLED";
      };
      storage = universalAccess "AccessibilityReaderAutoStartSpeaking";
      control = "AXCheckBox:AX_READER_AUTO_SPEAK";
    };

    voices = spokenSettings.preference "System voice" {
      spokenContent = accessibility "SpokenContentDefaultVoiceSelectionsByLanguage";
      announcementVoice = speech "TalkingAlertsSelectedVoiceID";
      announcementVoiceCreator = speech "TalkingAlertsSelectedVoiceCreator";
    } snapshot;

    accessibilityReader.shortcuts = spokenSettings.setting {
      ui = [
        "Accessibility Reader (i)"
        "Accessibility Reader shortcuts"
      ];
      storage.hotKey = universalAccess "AccessibilityReaderHotkey";
      value = snapshot;
    };

    accessibilityReader.automaticallyApplyFormatting = spoken {
      ui = "Automatically apply formatting";
      sheet = {
        ui = "Accessibility Reader";
        id = "AX_READER_HOTKEY_ENABLED";
      };
      storage = accessibility "AccessibilityReaderContentCleanUpBehavior";
      value = boolAs "always" "never";
      control = "AXCheckBox:AX_READER_CONTENT_CLEANUP";
    };

    speakSelectionOptions = {
      keyboardShortcut = spokenSettings.setting {
        ui = [
          "Speak selection (i)"
          "Keyboard shortcut"
        ];
        description = "A key code plus modifier values (⌘ 256, ⇧ 512, ⌥ 2048, ⌃ 4096); the default ⌥Esc is 2101.";
        storage = speech "SpokenUIUseSpeakingHotKeyCombo";
        value = numberBetween 0 65535;
      };

      highlightContent = spoken {
        ui = "Highlight content";
        sheet = speakSelectionSheet;
        storage = universalAccess "speakSelectionHighlightOptions";
        value = enum {
          None = 0;
          Words = 1;
          Sentences = 2;
          "Words and Sentences" = 3;
        };
        control = "AXPopUpButton:AX_SPOKEN_SELECTION_HIGHLIGHT_CONTENT";
        expect = {
          Words = "Words";
          None = "None";
        };
      };

      wordColor = spoken {
        ui = "Word color";
        sheet = speakSelectionSheet;
        storage = universalAccess "speakSelectionWordHighlightColor";
        value = highlightColors;
        control = "AXPopUpButton:AX_SPOKEN_SELECTION_HIGHLIGHT_WORD_COLOR";
        expect = {
          Default = "Default";
          Green = "Green";
        };
      };

      sentenceColor = spoken {
        ui = "Sentence color";
        sheet = speakSelectionSheet;
        storage = universalAccess "speakSelectionSentenceHighlightColor";
        value = highlightColors;
        control = "AXPopUpButton:AX_SPOKEN_SELECTION_HIGHLIGHT_SENTENCE_COLOR";
        expect = {
          Default = "Default";
          Green = "Green";
        };
      };

      sentenceStyle = spokenSettings.setting {
        ui = [
          "Speak selection (i)"
          "Sentence style"
        ];
        storage = universalAccess "speakSelectionSentenceStyle";
        value = enum {
          Underline = 0;
          "Background color" = 1;
        };
        verify = {
          open = [
            "AX_FEATURE_SPOKENCONTENT"
            "AX_SPOKEN_HOTKEY.infoButton"
          ];
          expect = {
            Underline = {
              "AXRadioButton:Underline + Sentence style" = 1;
            };
            "Background color" = {
              "AXRadioButton:Background color + Sentence style" = 1;
            };
          };
        };
      };

      showController = spoken {
        ui = "Show controller";
        sheet = speakSelectionSheet;
        storage = universalAccess "spokenContentControllerMode";
        value = enum {
          Automatically = 0;
          Never = 1;
          Always = 2;
        };
        control = "AXPopUpButton:AX_SPOKEN_SELECTION_SHOW_CONTROLLER";
        expect = {
          Automatically = "Automatically";
          Never = "Never";
        };
      };
    };

    speakAnnouncementsOptions = {
      phrase = control {
        page = "Read & Speak";
        pageId = "AX_FEATURE_SPOKENCONTENT";
        sheet = {
          ui = "Speak announcements";
          id = "AX_SPOKEN_ALERTS";
        };
        ui = "Phrase";
        storage = {
          speakPhrase = speech "TalkingAlertsSpeakPhraseFlag";
          strategy = speech "TalkingAlertsPhraseSelectionStrategy";
          index = speech "TalkingAlertsSelectedPhraseIndex";
        };
        value = enum (
          {
            "Application Name" = {
              speakPhrase = false;
            };
            "Next in Phrase List" = {
              speakPhrase = true;
              strategy = 1;
            };
            "Random from Phrase List" = {
              speakPhrase = true;
              strategy = 2;
            };
          }
          // lib.listToAttrs (
            lib.imap0
              (
                index: phrase:
                lib.nameValuePair phrase {
                  speakPhrase = true;
                  strategy = 0;
                  inherit index;
                }
              )
              [
                "Alert!"
                "Attention!"
                "Excuse me!"
                "Pardon me!"
              ]
          )
        );
        control = "AXPopUpButton:AX_SPEECH_PHRASE";
        expect = {
          "Alert!" = "Alert!";
          "Application Name" = "Application Name";
        };
      };

      delay = spokenSettings.setting {
        ui = [
          "Speak announcements (i)"
          "Delay"
        ];
        description = "Seconds before an alert is announced.";
        storage = speech "TalkingAlertsStartDelay";
        value = numberBetween 0.0 60.0;
      };
    };

    speakItemUnderThePointerOptions = {
      afterDelay = spokenSettings.setting {
        ui = [
          "Speak item under the pointer (i)"
          "After delay"
        ];
        description = "Seconds the pointer rests on an item before it's spoken.";
        storage = universalAccess "speakItemUnderMouseAfterDelayTime";
        value = numberBetween 0.0 5.0;
      };

      speak = spokenSettings.setting {
        ui = [
          "Speak item under the pointer (i)"
          "Speak item under the pointer"
        ];
        storage = universalAccess "speakItemUnderMouseAfterDelayMode";
        value = enum {
          "Only when zoomed" = 1;
          Always = 2;
        };
        verify = {
          open = [
            "AX_FEATURE_SPOKENCONTENT"
            "AX_SPOKEN_POINTER_ELEMENT.infoButton"
          ];
          expect = {
            "Only when zoomed" = {
              "AXRadioButton:Only when zoomed + Speak item under the pointer" = 1;
            };
            Always = {
              "AXRadioButton:Always + Speak item under the pointer" = 1;
            };
          };
        };
      };

      speechVerbosity = spoken {
        ui = "Speech verbosity";
        sheet = pointerSheet;
        storage = universalAccess "speakItemUnderMouseVerbosity";
        value = enum {
          High = 0;
          Medium = 1;
          Low = 2;
        };
        control = "AXPopUpButton:AX_SPOKEN_POINTER_ELEMENT_VERBOSITY";
        expect = {
          Low = "Low";
          High = "High";
        };
      };
    };

    typingFeedback = spokenSettings.setting {
      ui = "Speak typing feedback (i)";
      storage = universalAccess "typingEchoOptions";
      value = flagsWhenAbsent 5 {
        characters = 1;
        words = 4;
        selectionChanges = 8;
        modifierKeys = 16;
      };
    };
  };

  hoverText = {
    hoverText =
      hoverCheckbox "Hover Text" (universalAccess "hoverTextEnabled")
        "AXCheckBox:AX_HOVER_TEXT_ENABLE";

    hoverColor =
      hoverCheckbox "Hover Color" (universalAccess "hoverColorEnabled")
        "AXCheckBox:AX_HOVER_COLOR_ENABLE";

    hoverTyping =
      hoverCheckbox "Hover Typing" (universalAccess "hoverTypingEnabled")
        "AXCheckBox:AX_HOVER_TYPING_ENABLE";

    options = {
      activationModifier = hoverTextSettings.setting {
        ui = "Activation modifier";
        storage = universalAccess "hoverTextModifier";
        value = enum {
          "⌃ Control" = 0;
          "⌥ Option" = 1;
          "⌘ Command" = 2;
        };
      };

      textSize = hoverTextSettings.preference "Text size" (universalAccess "hoverTextFontSize") (
        numberBetween 12.0 128.0
      );

      textFont = hoverTextSettings.setting {
        ui = "Text font";
        description = "\"Default\" or the name of a font, e.g. \"Helvetica\".";
        storage = {
          font = universalAccess "hoverTextFont";
          style = universalAccess "hoverTextFontStyle";
        };
        value = fontCodec 13.0;
      };

      triplePressModifierToSetActivationLock = hover {
        ui = "Triple-press modifier to set activation lock";
        sheet = hoverTextSheet;
        storage = universalAccess "hoverTextActivationLockMode";
        value = integerBool;
        control = "AXCheckBox:AX_HOVER_TEXT_ACTIVATION_LOCK_MODE";
      };

      textColor =
        hoverColor hoverTextSheet "Text color" "hoverTextCustomFontColor"
          "AXPopUpButton:AX_HOVER_TEXT_FG_COLOR";

      backgroundColor =
        hoverColor hoverTextSheet "Background color" "hoverTextCustomBackgroundColor"
          "AXPopUpButton:AX_HOVER_TEXT_BG_COLOR";

      borderColor =
        hoverColor hoverTextSheet "Border color" "hoverTextBorderColor"
          "AXPopUpButton:AX_HOVER_TEXT_BORDER_COLOR";

      elementHighlightColor =
        hoverColor hoverTextSheet "Element-highlight color" "hoverTextElementHighlightColor"
          "AXPopUpButton:AX_HOVER_TEXT_ELEMENT_COLOR";
    };

    hoverTypingOptions = {
      textSize = preference [
        "Hover Text"
        "Hover Typing (i)"
        "Text size"
      ] (universalAccess "hoverTypingFontSize") (numberBetween 12.0 128.0);

      textFont = setting {
        ui = [
          "Hover Text"
          "Hover Typing (i)"
          "Text font"
        ];
        description = "\"Default\" or the name of a font, e.g. \"Helvetica\".";
        storage = {
          font = universalAccess "hoverTypingFont";
          style = universalAccess "hoverTypingFontStyle";
        };
        value = fontCodec 13.0;
      };

      textEntryLocation = hover {
        ui = "Text-entry location";
        sheet = hoverTypingSheet;
        storage = universalAccess "hoverTextTypingWindowPosition";
        value = enum {
          "Near Current Line" = 0;
          "Top Left" = 1;
          "Top Right" = 2;
          Custom = 5;
        };
        control = "AXPopUpButton:AX_HOVER_TYPING_ENTRY_LOCATION";
        expect = {
          "Near Current Line" = "Near Current Line";
          "Top Left" = "Top Left";
        };
      };

      textColor =
        hoverColor hoverTypingSheet "Text color" "hoverTypingCustomFontColor"
          "AXPopUpButton:AX_HOVER_TYPING_FG_COLOR";

      insertionPointColor =
        hoverColor hoverTypingSheet "Insertion-point color" "hoverTextCustomCursorColor"
          "AXPopUpButton:AX_HOVER_TYPING_INSERTION_COLOR";

      backgroundColor =
        hoverColor hoverTypingSheet "Background color" "hoverTypingCustomBackgroundColor"
          "AXPopUpButton:AX_HOVER_TYPING_BG_COLOR";

      borderColor =
        hoverColor hoverTypingSheet "Border color" "hoverTypingBorderColor"
          "AXPopUpButton:AX_HOVER_TYPING_BORDER_COLOR";

      elementHighlightColor =
        hoverColor hoverTypingSheet "Element-highlight color" "hoverTypingElementHighlightColor"
          "AXPopUpButton:AX_HOVER_TYPING_ELEMENT_COLOR";
    };
  };

  zoom = {
    useTrackpadGestureToZoom =
      zoomCheckbox "Use trackpad gesture to zoom" (universalAccess "closeViewTrackpadGestureZoomEnabled")
        "AXCheckBox:AX_ZOOM_TRACKPAD";

    useScrollGestureWithModifierKeysToZoom = zoom {
      ui = "Use scroll gesture with modifier keys to zoom";
      storage = {
        enabled = universalAccess "closeViewScrollWheelToggle";
      }
      // trackpad "HIDScrollZoomModifierMask";
      value =
        boolAs
          {
            enabled = true;
          }
          {
            enabled = false;
            builtIn = 0;
            bluetooth = 0;
          };
      control = "AXCheckBox:AX_ZOOM_ENABLE_GESTURE";
    };

    # Also turns on the Zoom shortcuts in Keyboard Shortcuts
    useKeyboardShortcutsToZoom = zoom {
      ui = "Use keyboard shortcuts to zoom";
      storage = {
        enabled = universalAccess "closeViewHotkeysEnabled";
        hotKeys = user "com.apple.symbolichotkeys" "AppleSymbolicHotKeys";
      };
      value = bool // {
        encode = keys: enabled: [
          (ops.write keys.enabled enabled)
          (ops.mergeDict keys.hotKeys (
            lib.genAttrs [ "15" "17" "19" "23" "179" ] (_: {
              inherit enabled;
            })
          ))
        ];
      };
      control = "AXCheckBox:AX_ZOOM_ENABLE_HOTKEYS";
      behaviors = [ activatesShortcuts ];
      # unset would delete every keyboard shortcut on the Mac
      canUnset = false;
    };

    modifierKeyForScrollGesture = setting {
      ui = [
        "Zoom"
        "Modifier key for scroll gesture"
      ];
      storage = {
        zoom = universalAccess "closeViewScrollWheelModifiersInt";
      }
      // trackpad "HIDScrollZoomModifierMask";
      value = {
        kind = "modifiers";
        type = lib.types.submodule {
          options = lib.mapAttrs (
            _: _:
            lib.mkOption {
              type = lib.types.bool;
              default = false;
            }
          ) modifierMask;
        };
        choices = lib.attrNames modifierMask;
        examples = [ { control = true; } ];
        encode =
          keys: modifiers:
          let
            mask = lib.foldl' (
              sum: name: sum + (if modifiers.${name} or false then modifierMask.${name} else 0)
            ) 0 (lib.attrNames modifierMask);
          in
          map (key: ops.write key mask) (lib.attrValues keys);
        fromName = builtins.fromJSON;
      };
    };

    zoomStyle = zoom {
      ui = "Zoom style";
      storage = universalAccess "closeViewZoomMode";
      value = enum {
        "Full Screen" = 0;
        "Picture-in-Picture" = 1;
        "Split Screen" = 2;
      };
      control = "AXPopUpButton:AX_ZOOM_STYLE_POPUP";
      expect = {
        "Full Screen" = "Full Screen";
        "Split Screen" = "Split Screen";
      };
    };
  };

  zoomAdvanced =
    let
      sheet = {
        ui = "Advanced…";
        open = "Advanced…";
      };
      advancedCheckbox = settingsLib.checkbox advanced;
      advanced = args: zoom (args // { inherit sheet; });
      zoomFactor =
        ui: key: control:
        advanced {
          inherit ui control;
          storage = universalAccess key;
          value = numberBetween 1.0 40.0;
          expect = { };
        };
    in
    {
      zoomedImageMoves = zoomAdvancedSettings.radio {
        ui = "Zoomed image moves";
        storage = universalAccess "closeViewPanningMode";
        value = enum {
          "Continuously with pointer" = 0;
          "When pointer reaches edge" = 1;
          "To keep pointer centered" = 2;
        };
      };

      restoreZoomFactorOnStartup =
        advancedCheckbox "Restore zoom factor on startup"
          (universalAccess "closeViewRestoreZoomFactorOnStartup")
          "AXCheckBox:AX_ZOOM_RESTORE";

      smoothImages =
        advancedCheckbox "Smooth images" (universalAccess "closeViewSmoothImages")
          "AXCheckBox:AX_ZOOM_SMOOTH";

      flashScreenWhenNotificationBannerAppearsOutsideZoomView =
        advancedCheckbox "Flash screen when notification banner appears outside zoom view"
          (universalAccess "closeViewFlashScreenOnNotificationEnabled")
          "AXCheckBox:AX_ZOOM_FLASH";

      disableUniversalControlWhileZoomedIn =
        advancedCheckbox "Disable Universal Control while zoomed in"
          (universalAccess "closeViewDisableUniversalControl")
          "AXCheckBox:AX_ZOOM_DISABLE_UNIVERSAL_CONTROL";

      zoomEachDisplayIndependently =
        advancedCheckbox "Zoom each display independently"
          (universalAccess "closeViewZoomIndividualDisplays")
          "AXCheckBox:AX_ZOOM_INDIVIDUAL_DISPLAYS";

      showZoomedImageWhileScreenSharing =
        advancedCheckbox "Show zoomed image while screen sharing"
          (universalAccess "closeViewZoomScreenShareEnabledKey")
          "AXCheckBox:AX_ZOOM_SCREEN_SHARE";

      useKeyboardShortcutsToAdjustZoomWindow =
        advancedCheckbox "Use keyboard shortcuts to adjust zoom window"
          (universalAccess "closeViewResizeHotKeysEnabled")
          "AXCheckBox:AX_ZOOM_RESIZE_SHORTCUTS";

      maximumZoom = zoomFactor "Maximum zoom" "closeViewNearPoint" "AXSlider:AX_ZOOM_MAX_FACTOR";
      minimumZoom = zoomFactor "Minimum zoom" "closeViewFarPoint" "AXSlider:AX_ZOOM_MIN_FACTOR";

      followKeyboardFocus = advanced {
        ui = "Follow keyboard focus";
        storage = universalAccess "closeViewZoomFocusFollowModeKey";
        value = enum {
          Never = 0;
          Always = 1;
          "When Typing" = 2;
        };
        control = "AXPopUpButton:AX_ZOOM_FOLLOW_FOCUS_MODE";
        expect = {
          Never = "Never";
          Always = "Always";
        };
      };

      moveScreenImageWhenFocusItemIs = advanced {
        ui = "Move screen image when focus item is";
        storage = universalAccess "closeViewZoomFocusActivationZone";
        value = enum {
          "Off-Center" = 0;
          "On Screen Edge" = 1;
          "Near Screen Edge" = 2;
        };
        control = "AXPopUpButton:AX_ZOOM_FOLLOW_FOCUS_ACTIVATION";
        expect = {
          "Near Screen Edge" = "Near Screen Edge";
          "Off-Center" = "Off-Center";
        };
      };

      moveScreenImage = zoomAdvancedSettings.radio {
        ui = "Move screen image";
        storage = universalAccess "closeViewZoomFocusMovement";
        value = enum {
          "So focus item is centered" = 0;
          "Just enough to show focus item" = 1;
        };
      };

      movementDelay = zoomAdvancedSettings.control {
        ui = "Movement speed";
        storage = universalAccess "closeViewZoomFocusMovementDelay";
        value = numberBetween 0.0 1.0;
        control = "AXSlider:AX_ZOOM_FOCUS_MOVEMENT_DELAY";
        expect = {
          "0.2" = 0.30000001192092896;
          "0.8" = 0.05000000074505806;
        };
      };

      toggleBetweenFullScreenAndPictureInPicture =
        advancedCheckbox "Toggle between full screen and picture-in-picture"
          (universalAccess "closeViewQuickSwitchHotKeysEnabled")
          "AXCheckBox:AX_ZOOM_TOGGLE_FS_AND_PIP";

      moveCursorToNextMonitor =
        advancedCheckbox "Move cursor to next monitor" (universalAccess "closeViewMonitorSelectionEnabled")
          "AXCheckBox:AX_ZOOM_MONITOR_SELECTION";

      useTrackpadGestureToMoveCursorBetweenMonitors = advanced {
        ui = "Use trackpad gesture to move cursor between monitors";
        storage = universalAccess "closeViewMonitorSelectionTrackpadGesture";
        value = enum {
          Off = 0;
          "Swipe with Three Fingers" = 1;
          "Swipe with Four Fingers" = 2;
          "Swipe with Five Fingers" = 3;
        };
        control = "AXPopUpButton:AX_ZOOM_MONITOR_SELECTION_TRACKPAD";
        expect = {
          Off = "Off";
          "Swipe with Three Fingers" = "Swipe with Three Fingers";
        };
      };

      invertColorsInPictureInPicture =
        zoomAdvancedSettings.preference "Invert colors" (universalAccess "closeViewInvertColors")
          bool;

      keepPictureInPictureWindowStationary =
        zoomAdvancedSettings.preference "Keep picture-in-picture window stationary"
          (universalAccess "closeViewKeepZoomWindowStationary")
          bool;

      modifiersForTemporaryActions = {
        toggleZoom =
          advancedCheckbox "Toggle zoom" (universalAccess "closeViewPressOnReleaseOff")
            "AXCheckBox:AX_ZOOM_TEMP_TOGGLE";

        detachZoomViewFromPointer =
          advancedCheckbox "Detach zoom view from pointer" (universalAccess "closeViewTemporaryDetachEnabled")
            "AXCheckBox:AX_ZOOM_TEMP_DETACH";

        disablePanning =
          advancedCheckbox "Disable panning" (universalAccess "closeViewTemporaryFreezePanningEnabled")
            "AXCheckBox:AX_ZOOM_FREEZE_PANNING";
      };
    };

  keyboard = {
    fullKeyboardAccess = both {
      page = "Keyboard";
      ui = "Full Keyboard Access";
      accessibilityKey = "FullKeyboardAccessEnabled";
      universalAccessKey = "keyboardAccessEnabled";
    };

    stickyKeys = unverified (feature "Keyboard" "Sticky Keys" "stickyKey" "AX_STICKY_KEYS");
    slowKeys = unverified (feature "Keyboard" "Slow Keys" "slowKey" "AX_SLOW_KEYS");
    accessibilityKeyboard =
      feature "Keyboard" "Accessibility Keyboard" "virtualKeyboardOnOff"
        "AX_VIRTUAL_KEYBOARD";

    fullKeyboardAccessOptions =
      let
        sheet = {
          ui = "Full Keyboard Access";
          id = "AX_FKA_ENABLE_CHECKBOX";
        };
      in
      {
        autoHide = keyboard {
          ui = "Auto-Hide";
          inherit sheet;
          storage = universalAccess "keyboardAccessFocusRingTimeoutEnabled";
          control = "AXCheckBox:AX_FKA_AUTO_HIDE_CHECKBOX";
        };

        increaseSize = keyboard {
          ui = "Increase size";
          inherit sheet;
          storage = universalAccess "keyboardAccessLargeFocusRingEnabled";
          control = "AXCheckBox:AX_FKA_INCREASE_SIZE_CHECKBOX";
        };

        highContrast = keyboard {
          ui = "High contrast";
          inherit sheet;
          storage = universalAccess "keyboardAccessFocusRingHighContrastEnabled";
          control = "AXCheckBox:AX_FKA_HIGH_CONTRAST_CHECKBOX";
        };

        color = keyboard {
          inherit sheet;
          ui = "Color";
          storage = universalAccess "keyboardAccessFocusRingColor";
          value = enumDict {
            Default = { };
            Yellow = rgb 1.0 0.8 0.0;
            Orange = rgb 1.0 0.5843137254901961 0.0;
            Gray = rgb 0.6 0.6 0.6;
            Green = rgb 0.2980392156862745 0.8509803921568627 0.39215686274509803;
            Red = rgb 1.0 0.23137254901960785 0.18823529411764706;
            Blue = rgb 0.0 0.47843137254901963 1.0;
            White = rgb 1.0 1.0 1.0;
          };
          control = "AXPopUpButton:AX_FKA_COLOR_POP_UP";
          expect = {
            Default = "Default";
            Yellow = "Yellow";
          };
        };
      };

    stickyKeysOptions =
      let
        sheet = {
          ui = "Sticky Keys";
          id = "AX_STICKY_KEYS";
        };
      in
      {
        beepWhenAModifierKeyIsSet = keyboard {
          ui = "Beep when a modifier key is set";
          inherit sheet;
          storage = universalAccess "stickyKeyBeepOnModifier";
          control = "AXCheckBox:AX_STICKY_KEYS_BEEP";
        };

        displayPressedKeysOnScreen = keyboard {
          ui = "Display pressed keys on screen";
          inherit sheet;
          storage = universalAccess "stickyKeyShowWindow";
          control = "AXCheckBox:AX_STICKY_KEYS_DISPLAY";
        };

        pressTheShiftKeyFiveTimesToToggleStickyKeys = unverified (keyboard {
          ui = "Press the Shift key five times to toggle Sticky Keys";
          inherit sheet;
          storage = universalAccess "useStickyKeysShortcutKeys";
          control = "AXCheckBox:AX_STICKY_KEYS_SHORTCUT";
        });

        screenAreaForDisplay = keyboard {
          inherit sheet;
          ui = "Screen area for display";
          storage = universalAccess "stickyKeysLocation";
          value = enum {
            "Top Right" = 0;
            "Top Left" = 1;
            "Bottom Right" = 2;
            "Bottom Left" = 3;
          };
          control = "AXPopUpButton:AX_STICKY_KEYS_DISPLAY_LOCATION";
          expect = {
            "Top Left" = "Top Left";
            "Bottom Right" = "Bottom Right";
          };
        };
      };

    slowKeysOptions =
      let
        sheet = {
          ui = "Slow Keys";
          id = "AX_SLOW_KEYS";
        };
      in
      {
        useClickKeySounds = keyboard {
          ui = "Use click key sounds";
          inherit sheet;
          storage = universalAccess "slowKeyBeepOn";
          control = "AXCheckBox:AX_SLOW_KEYS_SOUND";
        };

        acceptanceDelay = page.control {
          ui = [
            "Keyboard"
            "Slow Keys (i)"
            "Acceptance delay"
          ];
          description = "In milliseconds.";
          storage = universalAccess "slowKeyDelay";
          value = numberBetween 0 5000;
          control = "AXSlider:AX_SLOW_KEYS_DELAY";
          expect = {
            "250" = 250;
            "500" = 500;
          };
          verify.open = [
            "AX_FEATURE_KEYBOARD"
            "AX_SLOW_KEYS.infoButton"
          ];
        };
      };

    accessibilityKeyboardOptions =
      let
        sheet = {
          ui = "Accessibility Keyboard";
          id = "AX_VIRTUAL_KEYBOARD";
        };
      in
      {
        appearance = accessibilityKeyboardSettings.radio {
          ui = "Appearance";
          storage = universalAccess "virtualKeyboardTheme";
          value = enum {
            Light = "DisplayThemeDarkOnLight";
            Dark = "DisplayThemeLightOnDark";
          };
        };

        fadePanelAfterInactivity = keyboard {
          ui = "Fade panel after inactivity";
          inherit sheet;
          storage = universalAccess "dwellHideUIEnabled";
          control = "AXCheckBox:AX_KB_HIDE";
        };

        dwellCorners =
          let
            actions = {
              "Hide / Show Home Panel" = 1;
              "Toggle Dwell Pause" = 2;
              "Left Click" = 3;
              "Right Click" = 4;
              "Double Click" = 5;
              "Drag and Drop" = 6;
              "Scroll Menu" = 7;
              "Options Menu" = 8;
            };
            corner =
              ui: entry:
              accessibilityKeyboardSettings.select {
                inherit ui;
                storage = universalAccess "virtualKeyboardCornerActionType";
                value = inDict entry (enum actions);
                control = "AXPopUpButton:${ui}";
                choices = [
                  "Left Click"
                  "Hide / Show Home Panel"
                ];
                # unset would reset all four corners
                canUnset = false;
              };
          in
          {
            topLeft = corner "Top left corner" "2";
            topRight = corner "Top right corner" "3";
            bottomLeft = corner "Bottom left corner" "0";
            bottomRight = corner "Bottom right corner" "1";
          };

        dwellColor = keyboard {
          inherit sheet;
          ui = "Dwell color";
          storage = universalAccess "dwellCursorColorType";
          value = enum {
            Default = 0;
            White = 1;
            Blue = 2;
            Red = 3;
            Green = 4;
            Yellow = 5;
            Orange = 6;
          };
          control = "AXPopUpButton:AX_DWELL_CURSOR_COLOR";
          expect = {
            Default = "Default";
            Red = "Red";
          };
        };

        defaultDwellAction = keyboard {
          inherit sheet;
          ui = "Default dwell action";
          storage = {
            action = universalAccess "dwellActionType";
            enabled = universalAccess "dwellEnabled";
          };
          value = enum (
            {
              "Pause Dwell" = {
                action = 2;
                enabled = false;
              };
            }
            //
              lib.mapAttrs
                (_: action: {
                  inherit action;
                  enabled = true;
                })
                {
                  "Left Click" = 3;
                  "Right Click" = 4;
                  "Double Click" = 5;
                  "Drag and Drop" = 6;
                  "Scroll Menu" = 7;
                  "Options Menu" = 8;
                }
          );
          control = "AXPopUpButton:AX_DWELL_ACTION";
          expect = {
            "Pause Dwell" = "Pause Dwell";
            "Left Click" = "Left Click";
          };
        };

        defaultDwellTime = accessibilityKeyboardSettings.control {
          ui = "Default dwell time";
          description = "In seconds.";
          storage = universalAccess "dwellTimeDefaultAction";
          value = numberBetween 0.25 10.0;
          control = "AXIncrementor:AX_DWELL_WAIT_TIME";
          expect = {
            "1.5" = 1.5;
            "3.0" = 3.0;
          };
        };

        panelDwellTime = accessibilityKeyboardSettings.control {
          ui = "Panel dwell time";
          description = "In seconds.";
          storage = universalAccess "dwellTimeAssistiveControlUI";
          value = numberBetween 0.25 10.0;
          control = "AXIncrementor:AX_DWELL_WAIT_TIME_HOME";
          expect = {
            "1.5" = 1.5;
            "2.0" = 2.0;
          };
        };

        dwellMovementTolerance = accessibilityKeyboardSettings.control {
          ui = "Dwell movement tolerance";
          description = "In points.";
          storage = universalAccess "dwellTolerance";
          value = numberBetween 0.0 100.0;
          control = "AXIncrementor:AX_DWELL_TOLERANCE";
          expect = {
            "10.0" = 10.0;
            "20.0" = 20.0;
          };
        };

        postActionMovementTolerance = accessibilityKeyboardSettings.control {
          ui = "Post-action movement tolerance";
          description = "In points.";
          storage = universalAccess "dwellRetriggerTolerance";
          value = numberBetween 0.0 100.0;
          control = "AXIncrementor:AX_DWELL_RETRIGGER_TOLERANCE";
          expect = {
            "10.0" = 10.0;
            "20.0" = 20.0;
          };
        };

        fadeAfter = accessibilityKeyboardSettings.setting {
          ui = "Fade after";
          description = "In seconds.";
          storage = universalAccess "dwellHideUITimeout";
          value = numberBetween 1.0 60.0;
        };

        fadeBy = accessibilityKeyboardSettings.setting {
          ui = "Fade by";
          storage = universalAccess "virtualKeyboardHideUITransparencyLevel";
          value = numberBetween 0.0 1.0 // {
            encode = keys: amount: [ (ops.write keys.value (1.0 - amount)) ];
            decode =
              keys: get:
              let
                stored = get keys.value;
              in
              if stored == null then null else 1.0 - stored;
          };
        };

        zoomAfter = accessibilityKeyboardSettings.setting {
          ui = "Zoom after";
          description = "In seconds.";
          storage = universalAccess "dwellTimeZoom";
          value = numberBetween 0.25 10.0;
        };

        keysShouldBeEnteredOn = accessibilityKeyboardSettings.radio {
          ui = "Keys should be entered on";
          storage = universalAccess "virtualKeyboardMouseOption";
          value = enum {
            "Mouse down" = 0;
            "Mouse up" = 1;
          };
        };

        playSoundsForKeysAndDwellActions = keyboard {
          ui = "Play sounds for keys and dwell actions";
          inherit sheet;
          storage = universalAccess "virtualKeyboardPlaySounds";
          control = "AXCheckBox:AX_KB_USE_CLICK_SOUNDS";
        };

        keysCanBeSelectedUsingRightClick = keyboard {
          ui = "Keys can be selected using right-click";
          inherit sheet;
          storage = universalAccess "virtualKeyboardUseRightClick";
          control = "AXCheckBox:AX_KB_RIGHT_CLICK";
        };

        # Shared with Switch Control's keyboard
        insertAndRemoveSpacesAutomatically = keyboard {
          ui = "Insert and remove spaces automatically";
          inherit sheet;
          storage = universalAccess "AssistiveControlAutomaticSpaceEnabled";
          control = "AXCheckBox:AX_KB_AUTO_SPACING";
        };

        # Shared with Switch Control's keyboard
        capitalizeSentencesAutomatically = keyboard {
          ui = "Capitalize sentences automatically";
          inherit sheet;
          storage = universalAccess "AssistiveControlAutomaticShiftEnabled";
          control = "AXCheckBox:AX_KB_AUTO_CAPITALIZATION";
        };

        panelFollowsHideShowHomePanel = keyboard {
          ui = "Panel follows hide/show home panel";
          inherit sheet;
          storage = universalAccess "dwellHomePanelFollowTriggeredHotCornerEnabled";
          control = "AXCheckBox:AX_HOT_CORNER_MOVE_HOME_PANEL";
        };

        allowDwellActionsToolbarInPanels = keyboard {
          ui = "Allow dwell actions toolbar in panels";
          inherit sheet;
          storage = universalAccess "dwellShowActionsInPanels";
          control = "AXCheckBox:AX_HOME_PANEL_DWELL_ACTIONS";
        };

        showDwellActionsInMenuBar = keyboard {
          ui = "Show dwell actions in menu bar";
          inherit sheet;
          storage = universalAccess "dwellAlwaysShowMenuExtra";
          control = "AXCheckBox:AX_MENUBAR_DWELL_ACTIONS";
        };

        alwaysDwellInMenuExtras = keyboard {
          ui = "Always dwell in menu extras";
          inherit sheet;
          storage = universalAccess "dwellAlwaysAllowInMenuExtra";
          control = "AXCheckBox:AX_DWELL_IN_MENU_EXTRA";
        };

        alwaysDwellInPanels = keyboard {
          ui = "Always dwell in panels";
          inherit sheet;
          storage = universalAccess "dwellAlwaysAllowInPanels";
          control = "AXCheckBox:AX_DWELL_IN_PANELS";
        };

        enableZoom = keyboard {
          ui = "Enable zoom";
          inherit sheet;
          storage = universalAccess "dwellZoomEnabled";
          control = "AXCheckBox:AX_DWELL_ZOOM";
        };

        hideDwellTimeIndicators = keyboard {
          ui = "Hide dwell time indicators";
          inherit sheet;
          storage = universalAccess "dwellHideProgressIndicators";
          control = "AXCheckBox:AX_DWELL_PROGRESS_INDICATOR";
        };

        autoRevertToLeftClick = keyboard {
          ui = "Auto revert to left click";
          inherit sheet;
          storage = universalAccess "dwellAutoRevertToLeftClickEnabled";
          control = "AXCheckBox:AX_DWELL_AUTO_REVERT";
        };
      };
  };

  pointerControl = {
    mouseKeys = feature "Pointer Control" "Mouse Keys" "mouseDriver" "AX_MOUSE_KEYS";
    # The camera these use stays on after they're switched off until
    # universalaccessd restarts
    headPointer = switch {
      page = "Pointer Control";
      ui = "Head Pointer";
      control = "AX_HEAD_MOUSE";
      storage = universalAccess "headMouseEnabled";
      behaviors = [ (restarts "universalaccessd") ];
      sideEffects = "turns on the camera";
    };
    alternatePointerActions = switch {
      page = "Pointer Control";
      ui = "Alternate pointer actions";
      control = "AX_ALT_MOUSE_BUTTONS";
      storage = universalAccess "alternateMouseButtonsEnabled";
      behaviors = [ (restarts "universalaccessd") ];
      sideEffects = "can turn on the camera for facial expressions";
    };

    springLoading =
      pointerCheckbox "Spring-loading" (global "com.apple.springing.enabled")
        "AXCheckBox:AX_SPRING_LOADING";

    ignoreBuiltInTrackpadWhenMouseOrWirelessTrackpadIsPresent = pointer {
      ui = "Ignore built-in trackpad when mouse or wireless trackpad is present";
      storage = trackpad "USBMouseStopsTrackpad";
      value = eachKey integerBool;
      control = "AXCheckBox:AX_IGNORE_TRACKPAD";
    };

    doubleClickSpeed = setting {
      ui = [
        "Pointer Control"
        "Double-click speed"
      ];
      description = "The time between the clicks of a double-click, in seconds.";
      storage = global "com.apple.mouse.doubleClickThreshold";
      value = numberBetween 0.15 5.0;
    };

    springLoadingSpeed = page.control {
      ui = [
        "Pointer Control"
        "Spring-loading speed"
      ];
      description = "The delay before a folder springs open, in seconds; the slider shows 1 minus the delay.";
      storage = global "com.apple.springing.delay";
      value = numberBetween 0.0 2.0;
      control = "AXSlider:AX_SPRING_LOADING_DELAY";
      expect = {
        "0.5" = 0.5;
        "1.0" = 0.0;
      };
      verify.open = [ "AX_FEATURE_POINTERCONTROL" ];
    };

    trackpadOptions =
      let
        sheet = {
          ui = "Trackpad Options…";
          open = "Trackpad Options…";
        };
        byHostGlobal = name: byHost (global name);
      in
      {
        useTrackpadForScrolling = pointer {
          ui = "Use trackpad for scrolling";
          inherit sheet;
          storage = {
            behavior = byHostGlobal "com.apple.trackpad.scrollBehavior";
          }
          // lib.mapAttrs' (name: key: lib.nameValuePair "${name}Vertical" key) (trackpad "TrackpadScroll")
          // lib.mapAttrs' (name: key: lib.nameValuePair "${name}Horizontal" key) (
            trackpad "TrackpadHorizScroll"
          );
          value = boolKeys {
            behavior = boolAs 2 0;
            builtInVertical = bool;
            bluetoothVertical = bool;
            builtInHorizontal = bool;
            bluetoothHorizontal = bool;
          };
          control = "AXCheckBox:AX_TRACKPAD_SCROLL";
        };

        useInertiaWhenScrolling = pointer {
          ui = "Use inertia when scrolling";
          inherit sheet;
          storage = {
            global = byHostGlobal "com.apple.trackpad.momentumScroll";
          }
          // trackpad "TrackpadMomentumScroll";
          value = eachKey bool;
          control = "AXCheckBox:AX_TRACKPAD_SCROLL_BEHAVIOR";
        };

        scrollSpeed = preference [
          "Pointer Control"
          "Trackpad Options…"
          "Scroll speed"
        ] (global "com.apple.trackpad.scrolling") (numberBetween 0.0 1.0);

        # Tap to click writes the tap behavior too, so this writes it
        # afterwards. Three Finger Drag takes over the three-finger swipes
        dragging =
          let
            host = name: byHost (global name);
            tapBehavior =
              value:
              "/usr/bin/defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int ${toString value}";
            noTapDrag = "tap=$(/usr/bin/defaults -currentHost read NSGlobalDomain com.apple.mouse.tapBehavior 2>/dev/null); if [ \"$tap\" = 2 ] || [ \"$tap\" = 3 ]; then ${tapBehavior 1}; fi";
            style =
              {
                dragging,
                lock,
                threeFinger,
              }:
              {
                draggingBuiltIn = dragging;
                draggingBluetooth = dragging;
                lockBuiltIn = lock;
                lockBluetooth = lock;
                threeFingerBuiltIn = threeFinger;
                threeFingerBluetooth = threeFinger;
                threeFingerHost = threeFinger;
              }
              // lib.optionalAttrs threeFinger (lib.genAttrs threeFingerSwipes (_: 0));
            threeFingerSwipes = [
              "horizontalBuiltIn"
              "horizontalBluetooth"
              "horizontalHost"
              "verticalBuiltIn"
              "verticalBluetooth"
              "verticalHost"
            ];
            styles = {
              Off = style {
                dragging = false;
                lock = false;
                threeFinger = false;
              };
              "Without Drag Lock" = style {
                dragging = true;
                lock = false;
                threeFinger = false;
              };
              "With Drag Lock" = style {
                dragging = true;
                lock = true;
                threeFinger = false;
              };
              "Three Finger Drag" = style {
                dragging = false;
                lock = false;
                threeFinger = true;
              };
            };
            afterwards = {
              Off = noTapDrag;
              "Without Drag Lock" = tapBehavior 2;
              "With Drag Lock" = tapBehavior 3;
              "Three Finger Drag" = noTapDrag;
            };
            swipes = option: "applications.systemSettings.trackpad.moreGestures.${option}";
          in
          page.select {
            ui = [
              "Pointer Control"
              "Trackpad Options…"
              "Dragging style"
            ];
            description = "Off is Use trackpad for dragging turned off.";
            storage = {
              draggingBuiltIn = (trackpad "Dragging").builtIn;
              draggingBluetooth = (trackpad "Dragging").bluetooth;
              lockBuiltIn = (trackpad "DragLock").builtIn;
              lockBluetooth = (trackpad "DragLock").bluetooth;
              threeFingerBuiltIn = (trackpad "TrackpadThreeFingerDrag").builtIn;
              threeFingerBluetooth = (trackpad "TrackpadThreeFingerDrag").bluetooth;
              threeFingerHost = host "com.apple.trackpad.threeFingerDragGesture";
              horizontalBuiltIn = (trackpad "TrackpadThreeFingerHorizSwipeGesture").builtIn;
              horizontalBluetooth = (trackpad "TrackpadThreeFingerHorizSwipeGesture").bluetooth;
              horizontalHost = host "com.apple.trackpad.threeFingerHorizSwipeGesture";
              verticalBuiltIn = (trackpad "TrackpadThreeFingerVertSwipeGesture").builtIn;
              verticalBluetooth = (trackpad "TrackpadThreeFingerVertSwipeGesture").bluetooth;
              verticalHost = host "com.apple.trackpad.threeFingerVertSwipeGesture";
              tapBehavior = host "com.apple.mouse.tapBehavior";
            };
            # unset would delete the three-finger swipes too
            canUnset = false;
            value =
              let
                codec = enum styles;
              in
              codec
              // {
                encode = keys: label: codec.encode keys label ++ [ (ops.afterwards afterwards.${label}) ];
              };
            relations = [
              (allowedWhen "Without Drag Lock" "applications.systemSettings.trackpad.pointAndClick.tapToClick" (
                on: on
              ) "dragging is tap-and-drag")
              (allowedWhen "With Drag Lock" "applications.systemSettings.trackpad.pointAndClick.tapToClick" (
                on: on
              ) "dragging is tap-and-drag")
              (
                context:
                lib.optionals (context.value == "Three Finger Drag") (
                  lib.concatMap
                    (
                      option:
                      conflictsWith (swipes option) (
                        choice: lib.hasInfix "Three" choice
                      ) "Three Finger Drag takes the three-finger swipes" context
                    )
                    [
                      "swipeBetweenPages"
                      "swipeBetweenFullScreenApplications"
                      "missionControl"
                      "appExpose"
                    ]
                )
              )
            ];
            control = "AXPopUpButton:AX_TRACKPAD_DRAGGING_BEHAVIOR";
            choices = [
              "Without Drag Lock"
              "With Drag Lock"
            ];
            verify.open = [
              "AX_FEATURE_POINTERCONTROL"
              "Trackpad Options…"
            ];
          };
      };

    mouseOptions.scrollSpeed = preference [
      "Pointer Control"
      "Mouse Options…"
      "Scroll speed"
    ] (global "com.apple.scrollwheel.scaling") (numberBetween 0.0 1.0);

    mouseKeysOptions =
      let
        sheet = {
          ui = "Mouse Keys";
          id = "AX_MOUSE_KEYS";
        };
      in
      {
        pressTheOptionKeyFiveTimesToToggleMouseKeys = unverified (pointer {
          ui = "Press the Option key five times to toggle Mouse Keys";
          inherit sheet;
          storage = universalAccess "useMouseKeysShortcutKeys";
          control = "AXCheckBox:AX_MOUSE_KEYS_SHORTCUT";
        });

        ignoreBuiltInTrackpadWhenMouseKeysIsOn = unverified (pointer {
          ui = "Ignore built-in trackpad when Mouse Keys is on";
          inherit sheet;
          storage = universalAccess "mouseDriverIgnoreTrackpad";
          control = "AXCheckBox:AX_MOUSE_KEYS_IGNORE_TRACKPAD";
        });

        initialDelay = preference [
          "Pointer Control"
          "Mouse Keys (i)"
          "Initial delay"
        ] (universalAccess "mouseDriverInitialDelay") (numberBetween 0.0 4.0);

        maximumSpeed = setting {
          ui = [
            "Pointer Control"
            "Mouse Keys (i)"
            "Maximum speed"
          ];
          storage = universalAccess "mouseDriverMaxSpeed";
          value = number {
            min = 1;
            max = 40;
            stored = "float";
          };
        };
      };

    alternatePointerActionsOptions =
      let
        sheet = {
          ui = "Alternate pointer actions";
          id = "AX_ALT_MOUSE_BUTTONS";
        };
      in
      {
        playSounds = pointer {
          ui = "Play sounds";
          inherit sheet;
          storage = universalAccess "alternateMouseButtonsPlaySound";
          control = "AXCheckBox:AX_ALT_MOUSE_ENABLE_SOUNDS";
        };

        showActionsVisually = pointer {
          ui = "Show actions visually";
          inherit sheet;
          storage = universalAccess "alternateMouseButtonsShowVisualFeedback";
          control = "AXCheckBox:AX_ALT_MOUSE_ENABLE_VISUALS";
        };
      };

    headPointerOptions =
      let
        sheet = {
          ui = "Head Pointer";
          id = "AX_HEAD_MOUSE";
        };
      in
      {
        pointerMoves = headPointerSettings.setting {
          ui = "Pointer moves";
          storage = universalAccess "headMouseMode";
          value = enum {
            "When facing screen edges" = 1;
            "Relative to head movement" = 2;
          };
        };

        distanceToEdge = headPointerSettings.setting {
          ui = "Distance to edge";
          description = "0 to 1; System Settings shows it as a percentage.";
          storage = universalAccess "headMouseTolerance";
          value = numberBetween 0.0 1.0;
        };

        pointerSpeed =
          headPointerSettings.preference "Pointer speed" (universalAccess "headMouseSensitivity")
            (numberBetween 0.0 1.0);

        useASwitchOrFacialExpressionToPauseOrResume = pointer {
          ui = "Use a switch or facial expression to pause or resume";
          inherit sheet;
          storage = universalAccess "headMousePauseResumeSwitchEnabled";
          control = "AXCheckBox:AX_HEAD_MOUSE_PAUSE_RESUME";
        };

        useASwitchOrFacialExpressionToRecalibrate = pointer {
          ui = "Use a switch or facial expression to recalibrate";
          inherit sheet;
          storage = universalAccess "headMouseRecalibrateSwitchEnabled";
          control = "AXCheckBox:AX_HEAD_MOUSE_RECALIBRATE";
        };
      };
  };

  audioDescriptions.playAudioDescriptionsWhenAvailable = control {
    page = "Audio Descriptions";
    pageId = "AX_FEATURE_DESCRIPTIONS";
    ui = "Play audio descriptions when available";
    storage = mediaAccessibility "MAAudibleMediaPrefPreferDescriptiveVideo";
    control = "AXCheckBox:AX_VIDEO_DESCRIPTION";
  };

  liveCaptions = {
    liveCaptions = switch {
      page = "Live Captions";
      ui = "Live Captions";
      control = "AX_SYSTEM_TRANSCRIPTION_ENABLED";
      storage = universalAccess "systemTranscriptionEnabled";
      sideEffects = "turns on the microphone";
    };

    language = liveCaptionsSettings.setting {
      ui = "Language";
      description = "A locale such as \"en-US\" or \"en-GB\".";
      storage = accessibility "kAXSLiveCaptionsSelectedLocationPreference";
      value = text;
    };

    fontFamily = liveCaptionsSettings.setting {
      ui = "Font family";
      description = "\"Default\" or the name of a font, e.g. \"Helvetica\".";
      storage.font = universalAccess "systemTranscriptionTranscriptionViewFont";
      value = fontCodec 32.0;
    };

    fontSize =
      liveCaptionsSettings.preference "Font size"
        (universalAccess "systemTranscriptionTranscriptionViewFontSize")
        (numberBetween 12.0 120.0);

    fontColor =
      liveCaptionsSettings.preference "Font color"
        (universalAccess "systemTranscriptionTranscriptionViewFontColor")
        rgba;

    backgroundColor =
      liveCaptionsSettings.preference "Background color"
        (universalAccess "systemTranscriptionTranscriptionViewBackgroundColor")
        rgba;

    liveCaptionsInFaceTime = control {
      page = "Live Captions";
      pageId = "AX_FEATURE_SYSTEMTRANSCRIPTION";
      ui = "Live Captions in FaceTime";
      storage = accessibility "FaceTimeCaptions";
      value = integerBool;
      control = "AXCheckBox:AX_FACETIME_TRANSCRIPTIONS";
    };
  };

  siri.listenForAtypicalSpeech = control {
    page = "Siri";
    pageId = "AX_FEATURE_SIRI";
    ui = "Listen for atypical speech";
    storage = user "com.apple.assistant.backedup" "Use Atypical Speech Model";
    control = "AXCheckBox:AX_SIRI_ATYPICAL_SPEECH";
  };

  shortcut = {
    features = setting {
      ui = "Shortcut";
      storage = universalAccess "axShortcutExposedFeatures";
      value = dictSwitches (
        lib.mapAttrs (_: feature: "feature.${feature}") {
          voiceOver = "voiceOver";
          zoom = "zoom";
          hoverText = "hoverText";
          hoverTyping = "hoverTyping";
          invertDisplayColor = "invertDisplayColor";
          colorFilters = "displayFilters";
          accessibilityReader = "accessibilityReader";
          stickyKeys = "stickyKeys";
          slowKeys = "slowKeys";
          mouseKeys = "mouseKeys";
          fullKeyboardAccess = "fullKeyboardAccess";
          accessibilityKeyboard = "virtualKeyboard";
          increaseContrast = "increaseContrast";
          reduceTransparency = "reduceTransparency";
          showBorders = "showBorders";
          headPointer = "headMouse";
          voiceControl = "voiceControl";
          liveCaptions = "systemTranscriptions";
          liveSpeech = "liveSpeech";
          vehicleMotionCues = "motionCues";
          backgroundSounds = "backgroundSounds";
        }
      );
    };

    speech = control {
      page = "Shortcut";
      pageId = "AX_FEATURE_SHORTCUT";
      ui = "Speech";
      storage = universalAccess "axShortcutSpeechEnabled";
      control = "AXCheckBox:AX_SHORTCUT_SPEECH";
    };
  };

  voiceControl =
    let
      speechRecognition = user "com.apple.speech.recognition.AppleSpeechRecognition.prefs";
      voiceCheckbox = settingsLib.checkbox voice;
      voice = pageControl "Voice Control" "AX_FEATURE_VOICECONTROL";
    in
    {
      # The first time, turning it on downloads the speech models for the
      # language
      voiceControl = unverified (voice {
        ui = "Voice Control";
        storage = speechRecognition "DictationIMMasterDictationEnabled";
        control = "AXCheckBox:AX_VOICE_CONTROL_ENABLED";
      });

      language = setting {
        ui = [
          "Voice Control"
          "Language"
        ];
        description = "A locale such as \"en_US\".";
        storage = speechRecognition "DictationIMLocaleIdentifier";
        value = text;
      };

      microphone = setting {
        ui = [
          "Voice Control"
          "Microphone"
        ];
        description = "The microphone's device identifier, as Voice Control stores it.";
        storage = speechRecognition "DictationIMMicrophoneIdentifier";
        value = text;
      };

      showHints = voice {
        ui = "Show hints";
        storage = speechRecognition "CACUserHintsFeatures";
        value = boolAs 3 0;
        control = "AXCheckBox:AX_VOICE_CONTROL_SHOW_HINTS_ENABLED";
      };

      playSoundWhenCommandIsRecognized =
        voiceCheckbox "Play sound when command is recognized"
          (speechRecognition "DictationIMPlaySoundUponRecognition")
          "AXCheckBox:AX_VOICE_CONTROL_PLAY_SOUND_ENABLED";

      overlay = voice {
        ui = "Overlay";
        storage = speechRecognition "DictationIMAlwaysShowOverlayKey";
        value = enum {
          None = "None";
          "Item Numbers" = "NumberedElements";
          "Item Names" = "NamedElements";
          "Numbered Grid" = "NumberedGrid";
        };
        control = "AXPopUpButton:AX_VOICE_CONTROL_OVERLAY";
        expect = {
          None = "None";
          "Item Numbers" = "Item Numbers";
        };
      };

      fadeOverlayAfterInactivity =
        voiceCheckbox "Fade overlay after inactivity" (speechRecognition "CACOverlayFadingEnabled")
          "AXCheckBox:AX_VOICE_CONTROL_OVERLAY_FADING_ENABLED";
    };

  liveSpeech = {
    liveSpeech = feature "Live Speech" "Live Speech" "liveSpeechEnabled" "AX_LIVE_SPEECH_ENABLED";

    fontSize = preference [
      "Live Speech"
      "Font size"
    ] (universalAccess "liveSpeechFontSize") (numberBetween 12.0 120.0);

    voices = setting {
      ui = [
        "Live Speech"
        "Voice"
      ];
      storage.voices = universalAccess "liveSpeechLanguageVoiceSelections";
      value = snapshot;
    };
  };

  voiceOver.voiceOver = unverified (
    feature "VoiceOver" "VoiceOver" "voiceOverOnOffKey" "AX_VOICEOVER_ENABLED"
  );

  switchControl =
    let
      switchPageCheckbox = settingsLib.checkbox switchPage;
      switchPage = pageControl "Switch Control" "AX_FEATURE_SWITCHCONTROL";
    in
    {
      switchControl =
        feature "Switch Control" "Switch Control" "switchOnOffKey"
          "AX_SWITCH_CONTROL_ENABLE";

      appearance = switchControlSettings.radio {
        ui = "Appearance";
        storage = universalAccess "switchControlTheme";
        value = enum {
          Light = "DisplayThemeDarkOnLight";
          Dark = "DisplayThemeLightOnDark";
        };
      };

      fadePanelAfterInactivity =
        switchPageCheckbox "Fade panel after inactivity" (universalAccess "switchHideUIEnabled")
          "AXCheckBox:AX_SWITCH_HIDE_AFTER_DELAY";

      durationOfInactivity = switchControlSettings.setting {
        ui = "Duration of inactivity";
        description = "In seconds.";
        storage = universalAccess "switchHideUITimeout";
        value = numberBetween 1.0 120.0;
      };

      # The switch can only be changed while Switch Control is on
      autoScanning = unverified (switchPage {
        ui = "Auto scanning";
        storage = universalAccess "switchAutoScanEnabled";
        control = "AXCheckBox:AX_SWITCH_AUTOSCAN";
      });

      showCurrentTextInKeyboardPanel =
        switchPageCheckbox "Show current text in keyboard panel"
          (universalAccess "switchHoverTextToolbarEnabled")
          "AXCheckBox:AX_SWITCH_HOVER_TEXT_TOOLBAR";

      whileNavigating = switchPage {
        ui = "While navigating";
        storage = {
          sounds = universalAccess "switchPlaySounds";
          speak = universalAccess "switchSpeakSelectedElement";
        };
        value = enum {
          "Do nothing" = {
            sounds = false;
            speak = false;
          };
          "Play sounds" = {
            sounds = true;
            speak = false;
          };
          "Speak selection" = {
            sounds = false;
            speak = true;
          };
          "Speak & Play sounds" = {
            sounds = true;
            speak = true;
          };
        };
        control = "AXPopUpButton:AX_SWITCH_NAV_FEEDBACK";
        expect = {
          "Do nothing" = "Do nothing";
          "Play sounds" = "Play sounds";
        };
      };

      restartActionPosition = switchPage {
        ui = "Restart action position";
        storage = universalAccess "switchElementRestartOption";
        value = enum {
          "After cursor" = 0;
          "From start of group" = 1;
          "From the top" = 2;
        };
        control = "AXPopUpButton:AX_SWITCH_SCAN_RESTART";
        expect = {
          "After cursor" = "After cursor";
          "From the top" = "From the top";
        };
      };

      resumeAutoScanningAfterSelection =
        switchPageCheckbox "Resume auto scanning after selection"
          (universalAccess "switchResumeAutoScanningAfterSelectEnabled")
          "AXCheckBox:AX_SWITCH_RESUME_AUTO_SCANNING";

      reverseCursorDirectionAfterHittingEdge =
        switchPageCheckbox "Reverse cursor direction after hitting edge"
          (universalAccess "switchReverseMouseWhenReachingScreenEdge")
          "AXCheckBox:AX_SWITCH_MOUSE_CURSOR_EDGE";

      cursorSize = switchPage {
        ui = "Switch Control cursor size";
        storage = universalAccess "switchCursorSize";
        value = enum {
          Small = 1;
          Medium = 2;
          Large = 3;
        };
        control = "AXPopUpButton:AX_SWITCH_CURSOR_SIZE";
        expect = {
          Small = "Small";
          Large = "Large";
        };
      };

      holdBeforePerformDuration = switchTimingSettings.control {
        ui = "Hold before perform duration";
        description = "In seconds.";
        storage = universalAccess "switchMinimumPressDuration";
        value = numberBetween 0.0 10.0;
        control = "AXIncrementor:AX_SWITCH_MIN_DURATION";
        expect = {
          "0.0" = 0.0;
          "0.5" = 0.5;
        };
      };

      ignoreSwitchRepeats = switchTimingSettings.control {
        ui = "Ignore switch repeats";
        description = "In seconds.";
        storage = universalAccess "switchCoalescePressesDuration";
        value = numberBetween 0.0 10.0;
        control = "AXIncrementor:AX_SWITCH_COALESCE";
        expect = {
          "0.0" = 0.0;
          "0.5" = 0.5;
        };
      };

      holdBeforeRepeatDuration = switchTimingSettings.control {
        ui = "Hold before repeat duration";
        description = "In seconds.";
        storage = universalAccess "switchHoldBeforeRepeatDuration";
        value = numberBetween 0.0 10.0;
        control = "AXIncrementor:AX_SWITCH_REPEAT_HOLD";
        expect = {
          "1.0" = 1.0;
          "3.0" = 3.0;
        };
      };

      glidingAndRotatingCursorSpeed = navigationTimingSettings.control {
        ui = "Gliding & rotating cursor speed";
        description = "";
        storage = universalAccess "switchSweepingCursorSpeed";
        value = numberBetween 1.0 60.0;
        control = "AXIncrementor:AX_SWITCH_CURSOR_SPEED";
        expect = {
          "5.0" = 5.0;
          "10.0" = 10.0;
        };
      };

      autoScanningIntervalInPanels = navigationTimingSettings.control {
        ui = "Auto scanning interval in panels";
        description = "In seconds.";
        storage = universalAccess "switchAutoScanPanelInterval";
        value = numberBetween 0.1 10.0;
        control = "AXIncrementor:AX_SWITCH_SCAN_SPEED";
        expect = {
          "0.5" = 0.5;
          "1.0" = 1.0;
        };
      };

      autoScanningIntervalInInterface = navigationTimingSettings.control {
        ui = "Auto scanning interval in interface";
        description = "In seconds.";
        storage = universalAccess "switchAutoScanElementInterval";
        value = numberBetween 0.1 10.0;
        control = "AXIncrementor:AX_SWITCH_ELEMENT_SPEED";
        expect = {
          "0.5" = 0.5;
          "1.0" = 1.0;
        };
      };

      pauseOnFirstItem = navigationTimingSettings.control {
        ui = "Pause on first item";
        description = "In seconds.";
        storage = universalAccess "switchFirstElementDelay";
        value = numberBetween 0.0 10.0;
        control = "AXIncrementor:AX_SWITCH_FIRST_ITEM_DELAY";
        expect = {
          "0.0" = 0.0;
          "0.5" = 0.5;
        };
      };

      pointerPrecision = switchControlSettings.radio {
        ui = "Pointer precision";
        storage = universalAccess "switchMouseMoveStyle";
        value = enum {
          Low = 101;
          High = 102;
        };
      };

      loops = switchControlSettings.select {
        ui = "Loops";
        storage = universalAccess "switchScanCycleCount";
        value = numberBetween 1 10;
        control = "AXPopUpButton:AX_SWITCH_SCAN_CYCLE";
        choices = [
          "2"
          "4"
        ];
      };
    };

  rtt.rtt = control {
    page = "RTT";
    pageId = "AX_FEATURE_RTT";
    ui = "RTT";
    storage = user "com.apple.TTY" "TTYSoftwareEnabledPreference";
    value = inDict "RTTWildcardContext" bool;
    control = "AXCheckBox:AX_RTT_ENABLE";
  };

  rtt.sendImmediately = control {
    page = "RTT";
    pageId = "AX_FEATURE_RTT";
    ui = "Send immediately";
    storage = user "com.apple.TTY" "TTYShouldBeRealtimePreference";
    value = inDict "RTTWildcardContext" bool;
    control = "AXCheckBox:AX_RTT_SEND_IMMEDIATELY";
  };

  personalVoice.allowApplicationsToUseYourPersonalVoice = control {
    page = "Personal Voice";
    pageId = "AX_FEATURE_PERSONALVOICE";
    ui = "Allow applications to use your Personal Voice";
    storage = accessibility "kTTSVBAllowVoiceBankingAppUsage";
    control = "AXCheckBox:Allow applications to use your Personal Voice";
  };
}

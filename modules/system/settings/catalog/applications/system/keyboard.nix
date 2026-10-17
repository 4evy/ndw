{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Keyboard" "com.apple.settings.keyboard";
  inherit (page)
    setting
    select
    toggle
    preference
    ;

  inherit (settingsLib)
    eachKey
    bool
    boolAs
    numberBetween
    global
    user
    enum
    inDict
    hotKey
    activatesShortcuts
    shortcuts
    ops
    live
    strings
    ;

  inputSettings = page.navigate [
    "Text Input"
    "Input Sources"
    "Edit…"
  ] "Edit…";
  textInput = ui: storage: inputSettings.toggle { inherit ui storage; };
  hotKeys = user "com.apple.symbolichotkeys" "AppleSymbolicHotKeys";

  # testKeys differ per row so a category's rows can be verified together
  shortcut =
    {
      category,
      sidebar,
      ui,
      id,
      testKeys,
      group ? null,
      verifiable ? true,
    }:
    let
      rowSwitch = group == null || group.switches or true;
    in
    setting {
      ui = [
        "Keyboard Shortcuts…"
        category
      ]
      ++ lib.optional (group != null) group.name
      ++ [ ui ];
      description = ''
        false turns the shortcut off and true on while preserving its stored keys, keys such as "⌘⇧S" (⌃⌥⇧⌘
        and one key: a letter, digit or punctuation of the US layout, Space, Return, Tab, Delete,
        Escape, an arrow, Home, End, PageUp, PageDown, ForwardDelete or F1–F20) set its keys.
      '';
      storage = hotKeys;
      value = hotKey id;
      # unset would delete every keyboard shortcut on the Mac
      canUnset = false;
      behaviors = [ activatesShortcuts ];
      verify =
        if !verifiable then
          null
        else
          {
            open = [
              "AXButton:Keyboard Shortcuts…"
              "click:${sidebar}"
            ]
            ++ lib.optional (
              group != null
            ) "AXDisclosureTriangle:NSOutlineViewDisclosureButtonKey#${toString group.position}";
            # The row shows its keys on a button, between directional isolates
            expect =
              let
                keys = {
                  "AXButton:⁦${testKeys}⁩" = { };
                };
              in
              if rowSwitch then
                {
                  false = {
                    "AXCheckBox:${ui}" = 0;
                  };
                  ${testKeys} = keys // {
                    "AXCheckBox:${ui}" = 1;
                  };
                }
              else
                { ${testKeys} = keys; };
          };
    };

  domainOf = app: if app == "All Applications" then "NSGlobalDomain" else app;
  menuKeys =
    app: items:
    let
      escape = builtins.fromJSON ''"\u001b"'';
      title =
        path:
        let
          menus = lib.splitString "->" path;
        in
        if lib.length menus == 1 then path else lib.concatMapStrings (menu: escape + menu) menus;
      # cfprefsd puts a sandboxed app's preferences in its container
      domain = lib.escapeShellArg (domainOf app);
    in
    "/usr/bin/defaults write ${domain} NSUserKeyEquivalents -dict "
    + lib.concatStringsSep " " (
      lib.mapAttrsToList (
        path: keys:
        "${lib.escapeShellArg (title path)} ${lib.escapeShellArg (shortcuts.keyEquivalent keys)}"
      ) items
    );

  row = ui: id: { inherit ui id; };

  rowsOf =
    {
      category,
      sidebar,
      group ? null,
      verifiable ? true,
    }:
    rows:
    lib.mapAttrs (
      _: entry:
      shortcut {
        inherit
          category
          sidebar
          group
          verifiable
          ;
        inherit (entry) ui id;
        testKeys =
          "⌃⌥⇧⌘"
          + lib.elemAt (lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") (lib.mod entry.id 36);
      }
    ) rows;
in
{
  keyRepeatRate = setting {
    ui = "Key repeat rate";
    description = "Time between repeats, in 15 ms steps: lower is faster. System Settings offers 120, 90, 60, 30, 12, 6 and 2. Takes effect after logging out.";
    storage = global "KeyRepeat";
    value = numberBetween 1 120;
  };

  delayUntilRepeat = setting {
    ui = "Delay until repeat";
    description = "Time before a held key repeats, in 15 ms steps: lower is shorter. System Settings offers 120, 94, 68, 35, 25 and 15. Takes effect after logging out.";
    storage = global "InitialKeyRepeat";
    value = numberBetween 10 120;
  };

  pressGlobeKeyTo = select {
    ui = "Press 🌐︎ key to";
    storage = user "com.apple.HIToolbox" "AppleFnUsageType";
    value = enum {
      "Do Nothing" = 0;
      "Change Input Source" = 1;
      "Show Emoji & Symbols" = 2;
      "Start Dictation (Press 🌐︎ Twice)" = 3;
    };
    choices = [
      "Show Emoji & Symbols"
      "Change Input Source"
    ];
  };

  keyboardNavigation = toggle {
    ui = "Keyboard navigation";
    storage = global "AppleKeyboardUIMode";
    value = boolAs 2 0;
  };

  useF1F2EtcKeysAsStandardFunctionKeys = preference [
    "Keyboard Shortcuts…"
    "Function Keys"
    "Use F1, F2, etc. keys as standard function keys"
  ] (global "com.apple.keyboard.fnState") bool;

  textInput = {
    automaticallySwitchToADocumentsInputSource = inputSettings.setting {
      ui = "Automatically switch to a document’s input source";
      storage = user "com.apple.HIToolbox" "AppleGlobalTextInputProperties";
      value = inDict "TextInputGlobalPropertyPerContextInput" bool;
      canUnset = false;
    };

    inputSources = inputSettings.setting {
      ui = "All Input Sources";
      description = ''
        The keyboard layouts and input methods to have, by input source id, e.g.
        [ "com.apple.keylayout.US" "com.apple.keylayout.ABC" ]; the others are removed.
        `darwin-settings-current` lists the ones in use.
      '';
      storage = user "com.apple.HIToolbox" "AppleEnabledInputSources";
      value = strings;
      apply = live.inputSources;
      reads.command = live.enabledInputSources;
    };

    correctSpellingAutomatically = inputSettings.toggle {
      ui = "Correct spelling automatically";
      storage = {
        native = global "NSAutomaticSpellingCorrectionEnabled";
        web = global "WebAutomaticSpellingCorrectionEnabled";
      };
      value = eachKey bool;
    };

    capitalizeWordsAutomatically = textInput "Capitalize words automatically" (
      global "NSAutomaticCapitalizationEnabled"
    );
    showInlinePredictiveText = textInput "Show inline predictive text" (
      global "NSAutomaticInlinePredictionEnabled"
    );
    showSuggestedReplies = textInput "Show suggested replies" (global "NSSmartReplyEnabled");
    addPeriodWithDoubleSpace = textInput "Add period with double-space" (
      global "NSAutomaticPeriodSubstitutionEnabled"
    );

    useSmartQuotesAndDashes = inputSettings.toggle {
      ui = "Use smart quotes and dashes";
      storage = {
        quotes = global "NSAutomaticQuoteSubstitutionEnabled";
        dashes = global "NSAutomaticDashSubstitutionEnabled";
      };
      value = eachKey bool;
    };
  };

  keyboardShortcuts =
    let
      dock = {
        category = "Launchpad & Dock";
        sidebar = "Dock shortcuts";
      };
      display = {
        category = "Display";
        sidebar = "Display shortcuts";
      };
      missionControl = {
        category = "Mission Control";
        sidebar = "Mission Control shortcuts";
      };
      windows = {
        category = "Windows";
        sidebar = "Window management shortcuts";
      };
      keyboard = {
        category = "Keyboard";
        sidebar = "Keyboard shortcuts";
      };
      inputSources = {
        category = "Input Sources";
        sidebar = "Input Sources shortcuts";
      };
      screenshots = {
        category = "Screenshots";
        sidebar = "Screenshots shortcuts";
      };
      spotlight = {
        category = "Spotlight";
        sidebar = "Spotlight shortcuts";
      };
      accessibility = {
        category = "Accessibility";
        sidebar = "Accessibility shortcuts";
      };
      appShortcuts = {
        category = "App Shortcuts";
        sidebar = "Application shortcuts";
      };
      inGroup =
        category: position: name:
        category // { group = { inherit position name; }; };
      inGroupSwitchedAsOne =
        category: position: name:
        category
        // {
          group = {
            inherit position name;
            switches = false;
          };
        };
    in
    {
      launchpadAndDock = rowsOf dock {
        turnDockHidingOnOff = row "Turn Dock hiding on/off" 52;
      };

      display = rowsOf display {
        decreaseDisplayBrightness = row "Decrease display brightness" 53;
        increaseDisplayBrightness = row "Increase display brightness" 54;
      };

      missionControl =
        rowsOf missionControl {
          showNotificationCenter = row "Show Notification Center" 163;
          turnDoNotDisturbOnOff = row "Turn Do Not Disturb on/off" 175;
          turnStageManagerOnOff = row "Turn Stage Manager on/off" 222;
          quickNote = row "Quick Note" 190;
          gameOverlay = row "Game Overlay" 260;
        }
        // rowsOf (inGroup missionControl 1 "Mission Control") {
          moveLeftASpace = row "Move left a Space" 79;
          moveRightASpace = row "Move right a Space" 81;
          switchToDesktop1 = row "Switch to Desktop 1" 118;
        }
        // rowsOf (inGroup missionControl 1 "Mission Control" // { verifiable = false; }) (
          lib.listToAttrs (
            lib.genList (
              n:
              lib.nameValuePair "switchToDesktop${toString (n + 2)}" (
                row "Switch to Desktop ${toString (n + 2)}" (119 + n)
              )
            ) 15
          )
        );

      windows =
        rowsOf (inGroup windows 1 "General") {
          minimize = row "Minimize" 233;
          zoom = row "Zoom" 235;
          fill = row "Fill" 237;
          center = row "Center" 238;
          returnToPreviousSize = row "Return to Previous Size" 239;
        }
        // rowsOf (inGroup windows 2 "Halves") {
          tileLeftHalf = row "Tile Left Half" 240;
          tileRightHalf = row "Tile Right Half" 241;
          tileTopHalf = row "Tile Top Half" 242;
          tileBottomHalf = row "Tile Bottom Half" 243;
        }
        // rowsOf (inGroup windows 3 "Quarters") {
          tileTopLeftQuarter = row "Tile Top Left Quarter" 244;
          tileTopRightQuarter = row "Tile Top Right Quarter" 245;
          tileBottomLeftQuarter = row "Tile Bottom Left Quarter" 246;
          tileBottomRightQuarter = row "Tile Bottom Right Quarter" 247;
        }
        // rowsOf (inGroup windows 4 "Arrange") {
          arrangeLeftAndRight = row "Arrange Left and Right" 248;
          arrangeRightAndLeft = row "Arrange Right and Left" 249;
          arrangeTopAndBottom = row "Arrange Top and Bottom" 250;
          arrangeBottomAndTop = row "Arrange Bottom and Top" 251;
          arrangeInQuarters = row "Arrange in Quarters" 256;
        }
        // rowsOf (inGroup windows 5 "Full Screen Tile") {
          fullScreenTileLeft = row "Full Screen Tile Left" 257;
          fullScreenTileRight = row "Full Screen Tile Right" 258;
        };

      keyboard = rowsOf keyboard {
        changeTheWayTabMovesFocus = row "Change the way Tab moves focus" 13;
        turnKeyboardAccessOnOrOff = row "Turn keyboard access on or off" 12;
        moveFocusToTheMenuBar = row "Move focus to the menu bar" 7;
        moveFocusToTheDock = row "Move focus to the Dock" 8;
        moveFocusToActiveOrNextWindow = row "Move focus to active or next window" 9;
        moveFocusToTheWindowToolbar = row "Move focus to the window toolbar" 10;
        moveFocusToTheFloatingWindow = row "Move focus to the floating window" 11;
        moveFocusToNextWindow = row "Move focus to next window" 27;
        moveFocusToStatusMenus = row "Move focus to status menus" 57;
        showContextualMenu = row "Show contextual menu" 159;
      };

      inputSources = rowsOf inputSources {
        selectThePreviousInputSource = row "Select the previous input source" 60;
        selectNextSourceInInputMenu = row "Select next source in Input menu" 61;
      };

      screenshots = rowsOf screenshots {
        savePictureOfScreenAsAFile = row "Save picture of screen as a file" 28;
        copyPictureOfScreenToTheClipboard = row "Copy picture of screen to the clipboard" 29;
        savePictureOfSelectedAreaAsAFile = row "Save picture of selected area as a file" 30;
        copyPictureOfSelectedAreaToTheClipboard = row "Copy picture of selected area to the clipboard" 31;
        screenshotAndRecordingOptions = row "Screenshot and recording options" 184;
        askSiriAboutSelectedArea = row "Ask Siri about selected area" 261;
        askSiriAboutActiveWindow = row "Ask Siri about active window" 263;
      };

      spotlight = rowsOf spotlight {
        showSpotlightSearch = row "Show Spotlight search" 64;
        showFinderSearchWindow = row "Show Finder search window" 65;
        showApps = row "Show Apps" 160;
      };

      services = setting {
        ui = [
          "Keyboard Shortcuts…"
          "Services"
        ];
        description = ''
          Services, on or off, or on with keys such as "⌘⇧T", by the id macOS keeps them under:
          "<app's bundle identifier> - <menu title> - <method>", e.g.
          { "com.apple.Terminal - New Terminal at Folder - newTerminalAtFolder" = "⌘⇧T"; }.
          Services left out are left as they are; `darwin-settings-current` lists the ones that were
          changed in System Settings.
        '';
        storage = user "pbs" "NSServicesStatus";
        value = {
          kind = "services";
          decode =
            keys: get:
            let
              stored = get keys.value;
              choice =
                status:
                if !(status.enabled_services_menu or true) && !(status.enabled_context_menu or true) then
                  false
                else if (status.key_equivalent or "") != "" then
                  shortcuts.fromKeyEquivalent status.key_equivalent
                else
                  true;
            in
            if lib.isAttrs stored then lib.mapAttrs (_: choice) stored else null;
          type = lib.types.attrsOf (lib.types.either lib.types.bool shortcuts.type);
          choices = [ ];
          examples = [ { "com.apple.Terminal - New Terminal at Folder - newTerminalAtFolder" = "⌘⇧T"; } ];
          encode =
            keys: services:
            lib.optional (services != { }) (
              ops.mergeDict keys.value (
                lib.mapAttrs (
                  _: choice:
                  let
                    on = choice != false;
                  in
                  {
                    enabled_context_menu = on;
                    enabled_services_menu = on;
                    presentation_modes = {
                      ContextMenu = on;
                      ServicesMenu = on;
                    };
                  }
                  // lib.optionalAttrs (lib.isString choice) { key_equivalent = shortcuts.keyEquivalent choice; }
                ) services
              )
            );
          fromName = builtins.fromJSON;
        };
        # unset would reset every service
        canUnset = false;
        # Restarting pbs would lose the clipboard, so it's only told to update
        behaviors = [ (_: plan: plan ++ [ (ops.afterwards "/System/Library/CoreServices/pbs -update") ]) ];
        verify = {
          open = [
            "AXButton:Keyboard Shortcuts…"
            "click:Services shortcuts"
            "AXDisclosureTriangle:NSOutlineViewDisclosureButtonKey#1"
          ];
          expect = {
            ${
              builtins.toJSON { "com.apple.Automator - Create Service - makeNewServiceWithPasteboard" = "⌃⌥⇧⌘S"; }
            } =
              {
                "AXCheckBox:Create Service" = 1;
                "AXButton:⁦⌃⌥⇧⌘S⁩" = { };
              };
            ${
              builtins.toJSON { "com.apple.Automator - Create Service - makeNewServiceWithPasteboard" = false; }
            } =
              {
                "AXCheckBox:Create Service" = 0;
              };
          };
        };
      };

      appShortcuts =
        rowsOf (inGroup appShortcuts 1 "All Applications") {
          showHelpMenu = row "Show Help menu" 98;
        }
        // {
          menuItems = setting {
            ui = [
              "Keyboard Shortcuts…"
              "App Shortcuts"
            ];
            description = ''
              Keys for menu items, per app by bundle identifier or "All Applications", by the menu
              item's title; a title in a submenu is written with its menus, "Format->Font->Bold".
              Keys are written like "⌘⇧S" (see Keyboard Shortcuts…). Each app listed gets exactly
              these; apps left out keep theirs, e.g.
              { "com.apple.TextEdit" = { "Make Plain Text" = "⌘⇧T"; }; }.
            '';
            storage = {
              keys = global "NSUserKeyEquivalents" // {
                domain = "~/Library/Preferences/<application>";
              };
              apps = user "com.apple.universalaccess" "com.apple.custommenu.apps";
            };
            value = {
              kind = "applications";
              type = lib.types.attrsOf (lib.types.attrsOf shortcuts.type);
              choices = [ ];
              examples = [
                {
                  "com.apple.TextEdit" = {
                    "Make Plain Text" = "⌘⇧T";
                  };
                }
              ];
              encode =
                keys: apps:
                lib.optionals (apps != { }) (
                  lib.mapAttrsToList (app: items: ops.run (menuKeys app items)) apps
                  ++ [
                    (ops.setMembers keys.apps (lib.mapAttrs' (app: _: lib.nameValuePair (domainOf app) true) apps))
                  ]
                );
              fromName = builtins.fromJSON;
            };
            canUnset = false;
            reads = {
              command = ''
                printf '{'
                /usr/bin/defaults read com.apple.universalaccess com.apple.custommenu.apps 2>/dev/null | /usr/bin/tr -d ' ",()' | /usr/bin/grep . | while IFS= read -r app; do
                  items=$(/usr/bin/defaults export "$app" - | /usr/bin/plutil -extract NSUserKeyEquivalents json -o - - 2>/dev/null) || continue
                  printf '%s"%s":%s' "$separator" "$app" "$items"; separator=,
                done
                printf '}'
              '';
              parse = lib.mapAttrs' (
                domain: items:
                lib.nameValuePair (if domain == "NSGlobalDomain" then "All Applications" else domain) (
                  lib.mapAttrs' (
                    title: equivalent:
                    lib.nameValuePair (lib.concatStringsSep "->" (
                      lib.filter (part: part != "") (lib.splitString (builtins.fromJSON ''"\u001b"'') title)
                    )) (shortcuts.fromKeyEquivalent equivalent)
                  ) items
                )
              );
            };
            verify = {
              open = [
                "AXButton:Keyboard Shortcuts…"
                "click:Application shortcuts"
                "AXDisclosureTriangle:NSOutlineViewDisclosureButtonKey#2"
              ];
              expect = {
                ${
                  builtins.toJSON {
                    "com.apple.TextEdit" = {
                      "Format->Make Plain Text" = "⌃⌥⇧⌘T";
                    };
                  }
                } =
                  {
                    "AXHeading:TextEdit.app" = { };
                    "AXButton:⁦⌃⌥⇧⌘T⁩" = { };
                  };
              };
            };
          };
        };

      accessibility =
        rowsOf accessibility {
          invertColors = row "Invert colors" 21;
          showAccessibilityControls = row "Show Accessibility controls" 162;
          turnSpeakItemUnderThePointerOnOrOff = row "Turn speak item under the pointer on or off" 231;
          turnSpeakSelectionOnOrOff = row "Turn speak selection on or off" 230;
          turnTypingFeedbackOnOrOff = row "Turn typing feedback on or off" 232;
          turnVoiceOverOnOrOff = row "Turn VoiceOver on or off" 59;
        }
        // rowsOf (inGroupSwitchedAsOne accessibility 1 "Contrast") {
          increaseContrast = row "Increase contrast" 25;
          decreaseContrast = row "Decrease contrast" 26;
        }
        // rowsOf (inGroupSwitchedAsOne accessibility 2 "Live Captions") {
          turnLiveCaptionsOnOrOff = row "Turn Live Captions on or off" 215;
          pauseOrResumeTranscription = row "Pause or resume transcription" 216;
          turnTypeToSpeakOnOrOff = row "Turn type to speak on or off" 217;
          switchBetweenTranscribingComputerAudioAndMicrophone = row "Switch between transcribing computer audio and microphone" 218;
          turnKeepOnscreenOnOrOff = row "Turn keep onscreen on or off" 219;
        }
        // rowsOf (inGroupSwitchedAsOne accessibility 3 "Live Speech") {
          turnLiveSpeechOnOrOff = row "Turn Live Speech on or off" 225;
          toggleVisibility = row "Toggle visibility" 226;
          pauseOrResumeSpeech = row "Pause or resume speech" 227;
          cancelSpeech = row "Cancel speech" 228;
          hideOrShowPhrases = row "Hide or show phrases" 229;
        };
    };
}

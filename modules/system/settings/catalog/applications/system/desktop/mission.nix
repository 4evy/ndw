{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage [
    "Desktop & Dock"
    "Mission Control"
  ] "com.apple.settings.desktopAndDock";
  inherit (page) setting toggle;

  inherit (settingsLib)
    user
    global
    bool
    enum
    inverted
    restarts
    activatesShortcuts
    ops
    shortcuts
    ;

  hotKeys = user "com.apple.symbolichotkeys" "AppleSymbolicHotKeys";

  shift = shortcuts.modifiers."⇧".flag;
  modifierMasks = lib.mapAttrs (_: modifier: modifier.flag) shortcuts.modifiers;
  functionKey = shortcuts.functionFlag;
  keyCodes = lib.mapAttrs (_: key: key.code) (
    lib.getAttrs ((lib.genList (i: "F${toString (i + 1)}") 13) ++ arrows) shortcuts.namedKeys
  );
  arrows = [
    "←"
    "→"
    "↓"
    "↑"
  ];
  modifierKeys = {
    "Left Control" = 1;
    "Left Shift" = 2;
    "Right Shift" = 4;
    "Left Command" = 8;
    "Right Command" = 16;
    "Left Option" = 32;
    "Right Option" = 64;
    "Right Control" = 8192;
    fn = functionKey;
  };

  modifierCombinations = lib.foldr (
    glyph: rest: rest ++ map (combination: [ glyph ] ++ combination) rest
  ) [ [ ] ] (lib.reverseList (lib.attrNames modifierMasks));
  ordered = combination: lib.filter (glyph: lib.elem glyph combination) shortcuts.glyphOrder;

  off = {
    enabled = false;
  };
  standard = parameters: {
    enabled = true;
    value = {
      type = "standard";
      inherit parameters;
    };
  };
  modifier = mask: {
    enabled = true;
    value = {
      type = "modifier";
      parameters = [
        mask
        mask
      ];
    };
  };

  entries =
    ids: choice:
    let
      keyEntries = key: shifted: {
        ${toString ids.key} = key;
        ${toString ids.keyShifted} = shifted;
      };
      modifierEntries = plain: shifted: {
        ${toString ids.modifier} = plain;
        ${toString ids.modifierShifted} = shifted;
      };
    in
    if choice == "-" then
      keyEntries off off // modifierEntries off off
    else if modifierKeys ? ${choice} then
      keyEntries off off
      // modifierEntries (modifier modifierKeys.${choice}) (
        modifier (builtins.bitOr modifierKeys.${choice} shift)
      )
    else if lib.hasPrefix "fn F" choice then
      let
        key = lib.removePrefix "fn " choice;
      in
      keyEntries
        (standard [
          65535
          keyCodes.${key}
          functionKey
        ])
        (standard [
          65535
          keyCodes.${key}
          (functionKey + shift)
        ])
      // modifierEntries off off
    else
      let
        inherit (shortcuts.parse choice) modifiers key;
        mask = shortcuts.modifierMask modifiers + (if lib.elem key arrows then functionKey else 0);
      in
      keyEntries
        (standard [
          65535
          keyCodes.${key}
          mask
        ])
        (standard [
          65535
          keyCodes.${key}
          (builtins.bitOr mask shift)
        ])
      // modifierEntries off off;

  functionKeys = lib.filter (key: lib.hasPrefix "F" key) (lib.attrNames keyCodes);

  # macOS sets Show Desktop to fn F11, which System Settings shows as F11
  choices = [
    "-"
  ]
  ++ lib.attrNames modifierKeys
  ++ map (key: "fn ${key}") functionKeys
  ++ lib.concatMap (
    key: map (combination: lib.concatStrings (ordered combination) + key) modifierCombinations
  ) (lib.attrNames keyCodes);

  shortcut =
    { ui, ids }:
    setting {
      ui = [
        "Shortcuts…"
        ui
      ];
      description = ''
        "-" for none, a modifier key on its own ("Left Control", "fn", …), or a key with
        modifiers written as System Settings shows it: "F5", "⌃↑", "⌥⌘F1". "fn F11" is F11 with
        the function-key flag, the Show Desktop default.
      '';
      storage = hotKeys;
      value =
        enum (
          lib.genAttrs choices (choice: {
            value = entries ids choice;
          })
        )
        // {
          encode = keys: choice: [ (ops.mergeDict keys.value (entries ids choice)) ];
        };
      # unset would delete every keyboard shortcut on the Mac
      canUnset = false;
      behaviors = [ activatesShortcuts ];
      verify = {
        open = [ "Shortcuts…" ];
        expect = {
          "⌥F1" = {
            "AXPopUpButton:${ui}" = "⌥ F1";
          };
          "⌃F2" = {
            "AXPopUpButton:${ui}" = "⌃ F2";
          };
        };
      };
    };

  switchCheckbox = settingsLib.checkbox switch;
  switch = args: toggle ({ click = true; } // args);

  dockSwitchCheckbox = settingsLib.checkbox dockSwitch;
  dockSwitch = settingsLib.sectionWith switch {
    behaviors = [ (restarts "Dock") ];
  };
in
{
  automaticallyRearrangeSpacesBasedOnMostRecentUse =
    dockSwitchCheckbox "Automatically rearrange Spaces based on most recent use"
      (user "com.apple.dock" "mru-spaces")
      "auto-reorder-spaces";

  whenSwitchingToAnApplicationSwitchToAspaceWithOpenWindowsForTheApplication = switchCheckbox [
    "When switching to an application, switch to a Space with open windows for the application"
  ] (global "AppleSpacesSwitchOnActivate") "switch-space-on-active";

  groupWindowsByApplication =
    dockSwitchCheckbox "Group windows by application" (user "com.apple.dock" "expose-group-apps")
      "group-windows-by-application";

  displaysHaveSeparateSpaces = switch {
    ui = "Displays have separate Spaces";
    description = "Takes effect after logging out.";
    storage = user "com.apple.spaces" "spans-displays";
    value = inverted bool;
    control = "displays-have-separate-spaces";
  };

  dragWindowsToTopOfScreenToEnterMissionControl =
    dockSwitchCheckbox "Drag windows to top of screen to enter Mission Control"
      (user "com.apple.dock" "enterMissionControlByTopWindowDrag")
      "enter-mission-control-by-top-window-drag";

  shortcuts = {
    missionControl = shortcut {
      ui = "Mission Control";
      ids = {
        key = 32;
        keyShifted = 34;
        modifier = 44;
        modifierShifted = 46;
      };
    };

    # System Settings writes this one's Shift entries over Mission Control's
    # (34 and 46), so these are the ones macOS uses
    applicationWindows = shortcut {
      ui = "Application windows";
      ids = {
        key = 33;
        keyShifted = 35;
        modifier = 45;
        modifierShifted = 47;
      };
    };

    showDesktop = shortcut {
      ui = "Show Desktop";
      ids = {
        key = 36;
        keyShifted = 37;
        modifier = 48;
        modifierShifted = 49;
      };
    };
  };
}

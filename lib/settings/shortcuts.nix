{ lib }:
let
  /**
    Expose modifier glyph metadata for shortcut encoders

    Map each of ⌃, ⌥, ⇧, and ⌘ to an integer `flag` and AppKit `equivalent`

    # Type

    ```
    modifiers :: AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.modifiers` usage example

    ```nix
    s.shortcuts.modifiers."⌘"
    => { flag = 1048576; equivalent = "@"; }
    ```

    :::
  */
  modifiers = {
    "⌃" = {
      flag = 262144;
      equivalent = "^";
    };
    "⌥" = {
      flag = 524288;
      equivalent = "~";
    };
    "⇧" = {
      flag = 131072;
      equivalent = "$";
    };
    "⌘" = {
      flag = 1048576;
      equivalent = "@";
    };
  };

  /**
    Expose the native function-key modifier bit

    # Type

    ```
    functionFlag :: Int
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.functionFlag` usage example

    ```nix
    s.shortcuts.functionFlag
    => 8388608
    ```

    :::
  */
  functionFlag = 8388608;
  /**
    Expose the canonical modifier order used when decoding shortcuts

    # Type

    ```
    glyphOrder :: [String]
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.glyphOrder` usage example

    ```nix
    s.shortcuts.glyphOrder
    => [ "⌃" "⌥" "⇧" "⌘" ]
    ```

    :::
  */
  glyphOrder = [
    "⌃"
    "⌥"
    "⇧"
    "⌘"
  ];
  noCharacter = 65535;

  characterKeyCodes = {
    a = 0;
    s = 1;
    d = 2;
    f = 3;
    h = 4;
    g = 5;
    z = 6;
    x = 7;
    c = 8;
    v = 9;
    b = 11;
    q = 12;
    w = 13;
    e = 14;
    r = 15;
    y = 16;
    t = 17;
    "1" = 18;
    "2" = 19;
    "3" = 20;
    "4" = 21;
    "6" = 22;
    "5" = 23;
    "=" = 24;
    "9" = 25;
    "7" = 26;
    "-" = 27;
    "8" = 28;
    "0" = 29;
    "]" = 30;
    o = 31;
    u = 32;
    "[" = 33;
    i = 34;
    p = 35;
    l = 37;
    j = 38;
    "'" = 39;
    k = 40;
    ";" = 41;
    "\\" = 42;
    "," = 43;
    "/" = 44;
    n = 45;
    m = 46;
    "." = 47;
    "`" = 50;
  };

  /**
    Expose native metadata for named keys and F1 through F20

    Each entry contains `code`, `character`, `equivalent`, and `function`. Names
    include Space, Return, Tab, Delete, Escape, arrow glyphs, ForwardDelete,
    Home, End, PageUp, and PageDown

    # Type

    ```
    namedKeys :: AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.namedKeys` usage example

    ```nix
    s.shortcuts.namedKeys.Space.code
    => 49
    ```

    :::
  */
  namedKeys =
    let
      key = code: character: equivalent: function: {
        inherit
          code
          character
          equivalent
          function
          ;
      };
      char = unicode: builtins.fromJSON ''"\u${unicode}"'';
      functionKey = code: unicode: key code noCharacter (char unicode) true;
    in
    {
      Space = key 49 32 " " false;
      Return = key 36 noCharacter "\r" false;
      Tab = key 48 noCharacter "\t" false;
      Delete = key 51 noCharacter (char "0008") false;
      Escape = key 53 noCharacter (char "001b") false;
      "↑" = functionKey 126 "F700";
      "↓" = functionKey 125 "F701";
      "←" = functionKey 123 "F702";
      "→" = functionKey 124 "F703";
      ForwardDelete = functionKey 117 "F728";
      Home = functionKey 115 "F729";
      End = functionKey 119 "F72B";
      PageUp = functionKey 116 "F72C";
      PageDown = functionKey 121 "F72D";
    }
    // lib.listToAttrs (
      lib.imap1
        (n: code: lib.nameValuePair "F${toString n}" (functionKey code (lib.toHexString (63236 + n - 1))))
        [
          122
          120
          99
          118
          96
          97
          98
          100
          101
          109
          103
          111
          105
          107
          113
          106
          64
          79
          80
          90
        ]
    );
  /**
    Combine modifier glyphs into a native integer bit mask

    Duplicate glyphs do not change the result. Unknown glyphs fail lookup

    # Inputs

    `glyphs`
    : List containing only keys from `modifiers`

    # Type

    ```
    modifierMask :: [String] -> Int
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.modifierMask` usage example

    ```nix
    s.shortcuts.modifierMask [ "⌘" "⇧" ]
    => 1179648
    ```

    :::
  */
  modifierMask = glyphs: lib.foldl' builtins.bitOr 0 (map (glyph: modifiers.${glyph}.flag) glyphs);

  /**
    Parse modifier glyphs followed by one supported key

    Return `{ modifiers, key }` or null for unrecognized text. Accept modifiers
    in any order, including duplicates. Letter keys are case-insensitive and
    normalize to lowercase. Named keys are case-sensitive. Key codes use the US
    keyboard mapping encoded in this library

    # Inputs

    `text`
    : Shortcut string

    # Type

    ```
    parse :: String -> AttrSet | Null
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.parse` usage example

    ```nix
    s.shortcuts.parse "⌘⇧S"
    => { modifiers = [ "⌘" "⇧" ]; key = "s"; }
    ```

    :::
  */
  parse =
    text:
    let
      glyph = lib.findFirst (glyph: lib.hasPrefix glyph text) null (lib.attrNames modifiers);
      rest = parse (lib.removePrefix glyph text);
    in
    if glyph != null then
      (if rest == null then null else rest // { modifiers = [ glyph ] ++ rest.modifiers; })
    else if characterKeyCodes ? ${lib.toLower text} then
      {
        modifiers = [ ];
        key = lib.toLower text;
      }
    else if namedKeys ? ${text} then
      {
        modifiers = [ ];
        key = text;
      }
    else
      null;

  /**
    Check whether a string parses as a supported shortcut

    # Inputs

    `text`
    : String to check

    # Type

    ```
    isShortcut :: String -> Bool
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.isShortcut` usage example

    ```nix
    s.shortcuts.isShortcut "⌘⇧S"
    => true
    ```

    :::
  */
  isShortcut = text: parse text != null;

  /**
    Provide a string option type checked by `isShortcut`

    # Type

    ```
    type :: OptionType
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.type` usage example

    ```nix
    s.shortcuts.type.check "⌘Space"
    => true
    ```

    :::
  */
  type = lib.types.addCheck lib.types.str isShortcut // {
    description = ''a shortcut such as "⌘⇧S": ⌃⌥⇧⌘ followed by a key'';
  };

  /**
    Encode a shortcut as symbolic hotkey parameters

    Return `[ character, keyCode, flags ]`. Named function keys add the function
    modifier flag. Require input accepted by `parse`, otherwise evaluation fails

    # Inputs

    `text`
    : Supported shortcut string

    # Type

    ```
    hotKeyParameters :: String -> [Int]
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.hotKeyParameters` usage example

    ```nix
    s.shortcuts.hotKeyParameters "⌘⇧S"
    => [ 115 1 1179648 ]
    ```

    :::
  */
  hotKeyParameters =
    text:
    let
      shortcut = parse text;
      named = namedKeys.${shortcut.key} or null;
      flags = builtins.bitOr (modifierMask shortcut.modifiers) (
        if named != null && named.function then functionFlag else 0
      );
    in
    if named != null then
      [
        named.character
        named.code
        flags
      ]
    else
      [
        (lib.strings.charToInt shortcut.key)
        characterKeyCodes.${shortcut.key}
        flags
      ];

  /**
    Encode a shortcut as an AppKit key-equivalent string

    Emit modifiers in command, control, option, shift order, using `@`, `^`,
    `~`, and `$`. Require input accepted by `parse`

    # Inputs

    `text`
    : Supported shortcut string

    # Type

    ```
    keyEquivalent :: String -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.keyEquivalent` usage example

    ```nix
    s.shortcuts.keyEquivalent "⌘⇧S"
    => "@$s"
    ```

    :::
  */
  keyEquivalent =
    text:
    let
      shortcut = parse text;
      ordered = lib.filter (glyph: lib.elem glyph shortcut.modifiers) [
        "⌘"
        "⌃"
        "⌥"
        "⇧"
      ];
    in
    lib.concatMapStrings (glyph: modifiers.${glyph}.equivalent) ordered
    + (namedKeys.${shortcut.key}.equivalent or shortcut.key);

  /**
    Decode native symbolic hotkey parameters to a shortcut string

    Return null unless given three integers and a known key code. Infer the key
    from its code, ignoring the character field. Emit modifiers in `glyphOrder`
    with uppercase letter keys. Unrecognized modifier bits are ignored

    # Inputs

    `parameters`
    : Native parameter value to decode

    # Type

    ```
    fromHotKey :: Any -> String | Null
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.fromHotKey` usage example

    ```nix
    s.shortcuts.fromHotKey [ 115 1 1179648 ]
    => "⇧⌘S"
    ```

    :::
  */
  fromHotKey =
    parameters:
    let
      flags = lib.elemAt parameters 2;
      code = lib.elemAt parameters 1;
      key = lib.findFirst (name: characterKeyCodes.${name} == code) null (
        lib.attrNames characterKeyCodes
      );
      named = lib.findFirst (name: namedKeys.${name}.code == code) null (lib.attrNames namedKeys);
      glyphs = lib.filter (glyph: builtins.bitAnd flags modifiers.${glyph}.flag != 0) glyphOrder;
    in
    if !lib.isList parameters || lib.length parameters != 3 || !lib.all lib.isInt parameters then
      null
    else if key != null then
      lib.concatStrings glyphs + lib.toUpper key
    else if named != null then
      lib.concatStrings glyphs + named
    else
      null;

  /**
    Decode an AppKit key-equivalent string

    Normalize modifier order and letter case. Recognize named-key equivalents,
    but do not reject unknown key text. Validate the result with `isShortcut`
    when input is not known to be supported

    # Inputs

    `equivalent`
    : AppKit key-equivalent string

    # Type

    ```
    fromKeyEquivalent :: String -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shortcuts.fromKeyEquivalent` usage example

    ```nix
    s.shortcuts.fromKeyEquivalent "@$s"
    => "⇧⌘S"
    ```

    :::
  */
  fromKeyEquivalent =
    equivalent:
    let
      characters = lib.stringToCharacters equivalent;
      modifierOf =
        character:
        lib.findFirst (glyph: modifiers.${glyph}.equivalent == character) null (lib.attrNames modifiers);
      split =
        list:
        if lib.length list > 1 && modifierOf (lib.head list) != null then
          let
            rest = split (lib.tail list);
          in
          rest // { glyphs = [ (modifierOf (lib.head list)) ] ++ rest.glyphs; }
        else
          {
            glyphs = [ ];
            key = lib.concatStrings list;
          };
      parts = split characters;
      named = lib.findFirst (name: namedKeys.${name}.equivalent == parts.key) null (
        lib.attrNames namedKeys
      );
    in
    lib.concatStrings (lib.filter (glyph: lib.elem glyph parts.glyphs) glyphOrder)
    + (if named != null then named else lib.toUpper parts.key);
in
{
  # Share native key metadata with settings that offer a restricted key menu
  inherit
    modifiers
    namedKeys
    functionFlag
    glyphOrder
    modifierMask
    parse
    isShortcut
    type
    hotKeyParameters
    keyEquivalent
    fromHotKey
    fromKeyEquivalent
    ;
}

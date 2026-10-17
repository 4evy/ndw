{
  lib,
  ops,
  shortcuts,
}:
let
  single =
    keys:
    if keys ? value && lib.length (lib.attrNames keys) == 1 then
      keys.value
    else
      throw "this value type needs a single storage key, not a record";

  isAbsent = value: lib.isAttrs value && value._type or null == "absent";

  writeOrDelete = key: value: if isAbsent value then ops.delete key else ops.write key value;

  writeStored =
    keys: stored:
    if lib.isAttrs stored && !(isAbsent stored) then
      lib.mapAttrsToList (name: value: writeOrDelete keys.${name} value) stored
    else
      [ (writeOrDelete (single keys) stored) ];

  storedValue =
    codec: value:
    if codec ? table then
      let
        stored = codec.table.${value};
      in
      if lib.isAttrs stored && stored ? value then stored.value else stored
    else
      value;

  switchesType =
    names:
    lib.types.submodule {
      options = lib.mapAttrs (
        _: _:
        lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
        }
      ) names;
    };

  setSwitches =
    names: value:
    lib.filterAttrs (_: v: v != null) (lib.mapAttrs (name: _: value.${name} or null) names);

  bitSum = lib.foldl' builtins.bitOr 0;

  writeSingle = keys: value: [ (ops.write (single keys) value) ];

  readSingle = keys: get: if lib.attrNames keys == [ "value" ] then get keys.value else null;

  withoutDecode = codec: removeAttrs codec [ "decode" ];
  /**
    Represent deletion in an explicit stored-value mapping

    Use this sentinel in `boolAs`, `storedAs`, or `enum` tables. It produces a
    delete operation rather than storing a null or dictionary

    # Type

    ```
    absent :: AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.absent` usage example

    ```nix
    s.boolAs true s.absent
    ```

    :::
  */
  absent = {
    _type = "absent";
  };

  /**
    Encode a boolean as a single preference key

    Require a single key named `value`. `choices` is empty, while `examples`
    contains true and false. `fromName` returns true only for `"true"`

    # Type

    ```
    bool :: Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.bool` usage example

    ```nix
    s.bool.encode { value = s.global "AppleShowAllExtensions"; } true
    ```

    :::
  */
  bool = {
    kind = "bool";
    type = lib.types.bool;
    choices = [ ];
    examples = [
      true
      false
    ];
    encode = writeSingle;
    fromName = name: name == "true";
  };

  /**
    Invert a boolean before passing it to another codec

    Preserve the codec's type and metadata, and remove its decoder. Use this for
    preferences whose stored boolean has the opposite meaning from the option

    # Inputs

    `codec`
    : Boolean codec to invert

    # Type

    ```
    inverted :: Codec -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.inverted` usage example

    ```nix
    s.inverted s.integerBool
    ```

    :::
  */
  inverted =
    codec:
    withoutDecode codec
    // {
      encode = keys: value: codec.encode keys (!value);
    };

  /**
    Replace a codec's encoding with an explicit stored-value table

    Index the table with `builtins.toJSON value`. A dictionary is interpreted as
    a named storage-key record. Wrap a dictionary in `{ value = ...; }` to store
    it in a single key. `absent` deletes the corresponding key. Remove the
    inherited decoder because it no longer describes this mapping

    # Inputs

    `stored`
    : Attribute set keyed by JSON representations of option values

    `codec`
    : Codec whose accepted values and metadata are retained

    # Type

    ```
    storedAs :: AttrSet -> Codec -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.storedAs` usage example

    ```nix
    s.storedAs { true = 1; false = 0; } s.bool
    ```

    :::
  */
  storedAs =
    stored: codec:
    withoutDecode codec
    // {
      encode = keys: value: writeStored keys stored.${builtins.toJSON value};
    };

  /**
    Encode true and false using explicit stored values

    Accept scalars, `absent`, or records matching named storage keys. A
    dictionary for a single key must be wrapped in `{ value = ...; }`

    # Inputs

    `on`
    : Stored value for true

    `off`
    : Stored value for false

    # Type

    ```
    boolAs :: Any -> Any -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.boolAs` usage example

    ```nix
    s.boolAs 1 s.absent
    ```

    :::
  */
  boolAs =
    on: off:
    storedAs {
      true = on;
      false = off;
    } bool;

  /**
    Apply a single-key codec to every key in a storage record

    Emit operations in attribute-name order and remove the inherited decoder

    # Inputs

    `codec`
    : Codec that encodes a key record containing only `value`

    # Type

    ```
    eachKey :: Codec -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.eachKey` usage example

    ```nix
    s.eachKey s.integerBool
    ```

    :::
  */
  eachKey =
    codec:
    withoutDecode codec
    // {
      encode =
        keys: value: lib.concatMap (key: codec.encode { value = key; } value) (lib.attrValues keys);
    };

  /**
    Encode booleans as integers, using 1 for true and 0 for false

    # Type

    ```
    integerBool :: Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.integerBool` usage example

    ```nix
    s.integerBool.encode { value = s.global "ExampleEnabled"; } false
    ```

    :::
  */
  integerBool = boolAs 1 0;

  /**
    Encode one boolean through a different codec for each named key

    Each supplied codec receives the same boolean and its corresponding key. The
    key record must contain every name in `codecs`

    # Inputs

    `codecs`
    : Attribute set mapping storage-key names to boolean codecs

    # Type

    ```
    boolKeys :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.boolKeys` usage example

    ```nix
    s.boolKeys { enabled = s.bool; disabled = s.inverted s.integerBool; }
    ```

    :::
  */
  boolKeys =
    codecs:
    bool
    // {
      encode =
        keys: value:
        lib.concatLists (
          lib.mapAttrsToList (name: codec: codec.encode { value = keys.${name}; } value) codecs
        );
    };

  /**
    Merge a codec's stored value into one entry of a dictionary preference

    Use the codec's table mapping when present, otherwise use the option value.
    This wrapper does not compose arbitrary encode transformations. For example,
    `integerBool` has no table, so it would still store a boolean here.
    Unrelated dictionary entries are retained at execution time, and the decoder
    is removed

    # Inputs

    `entry`
    : Dictionary entry name

    `codec`
    : Codec providing the option type and optional stored-value table

    # Type

    ```
    inDict :: String -> Codec -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.inDict` usage example

    ```nix
    s.inDict "enabled" s.bool
    ```

    :::
  */
  inDict =
    entry: codec:
    withoutDecode codec
    // {
      encode = keys: value: [ (ops.mergeDict (single keys) { ${entry} = storedValue codec value; }) ];
    };

  /**
    Encode and decode a string in a single preference key

    # Type

    ```
    text :: Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.text` usage example

    ```nix
    s.text.type.check "hello"
    => true
    ```

    :::
  */
  text = {
    kind = "string";
    decode = readSingle;
    type = lib.types.str;
    choices = [ ];
    examples = [ "…" ];
    encode = writeSingle;
    fromName = name: name;
  };

  /**
    Encode and decode a list of strings in a single preference key

    Parse named values as JSON arrays through `fromName`

    # Type

    ```
    strings :: Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.strings` usage example

    ```nix
    s.strings.type.check [ "en-US" "bg-BG" ]
    => true
    ```

    :::
  */
  strings = {
    kind = "list";
    decode = readSingle;
    type = lib.types.listOf lib.types.str;
    choices = [ ];
    examples = [ [ "…" ] ];
    encode = writeSingle;
    fromName = builtins.fromJSON;
  };

  /**
    Encode a number within inclusive bounds

    Use a floating-point option type when either bound is a float or `stored` is
    `"float"`. Otherwise require integers. When reading an integer codec, accept
    integral floats within the bounds and convert them to integers

    # Inputs

    `min`
    : Inclusive lower bound

    `max`
    : Inclusive upper bound

    `stored`
    : Optional storage type override, defaulting to null

    `unit`
    : Optional descriptive unit for generated metadata, defaulting to null

    # Type

    ```
    number :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.number` usage example

    ```nix
    s.number { min = 0.0; max = 10.0; stored = "float"; unit = "seconds"; }
    ```

    :::
  */
  number =
    {
      min,
      max,
      stored ? null,
      unit ? null,
    }:
    let
      float = stored == "float" || lib.isFloat min || lib.isFloat max;
    in
    {
      kind = "number";
      decode =
        keys: get:
        let
          value = readSingle keys get;
        in
        if !float && lib.isFloat value && value >= min && value <= max && value == builtins.floor value then
          builtins.floor value
        else
          value;
      inherit min max unit;
      type = if float then lib.types.numbers.between min max else lib.types.ints.between min max;
      choices = [ ];
      examples = [
        min
        max
      ];
      encode =
        keys: value:
        let
          key = single keys;
        in
        [ (ops.write (if stored != null then key // { type = stored; } else key) value) ];
      fromName = builtins.fromJSON;
    };

  /**
    Create a numeric codec with inclusive bounds

    Equivalent to `number { inherit min max; }`

    # Inputs

    `min`
    : Inclusive lower bound

    `max`
    : Inclusive upper bound

    # Type

    ```
    numberBetween :: Number -> Number -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.numberBetween` usage example

    ```nix
    s.numberBetween 16 128
    ```

    :::
  */
  numberBetween = min: max: number { inherit min max; };

  /**
    Map option labels to stored values or named storage-key records

    The attribute names become accepted values, choices, and examples in
    attribute-name order. A dictionary value is a multi-key record. Use
    `enumDict` to store dictionaries in a single key. `absent` deletes a key

    # Inputs

    `table`
    : Attribute set mapping labels to stored values

    # Type

    ```
    enum :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.enum` usage example

    ```nix
    s.enum { Left = "left"; Bottom = "bottom"; Right = "right"; }
    ```

    :::
  */
  enum = table: {
    kind = "enum";
    inherit table;
    type = lib.types.enum (lib.attrNames table);
    choices = lib.attrNames table;
    examples = lib.attrNames table;
    encode = keys: label: writeStored keys table.${label};
    fromName = name: name;
  };

  /**
    Map option labels to dictionaries stored in a single preference key

    Wrap each dictionary so `enum` does not treat it as a multi-key record

    # Inputs

    `table`
    : Attribute set mapping labels to dictionary values

    # Type

    ```
    enumDict :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.enumDict` usage example

    ```nix
    s.enumDict { Red = s.rgb 1 0 0; Blue = s.rgb 0 0 1; }
    ```

    :::
  */
  enumDict = table: enum (lib.mapAttrs (_: value: { inherit value; }) table);

  /**
    Create an opaque plist color dictionary with real-valued components

    No range validation is performed

    # Inputs

    `red`
    : Red component

    `green`
    : Green component

    `blue`
    : Blue component

    # Type

    ```
    rgb :: Number -> Number -> Number -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.rgb` usage example

    ```nix
    s.rgb 1 0 0
    => { red = 1.0; green = 0.0; blue = 0.0; alpha = 1.0; }
    ```

    :::
  */
  rgb = red: green: blue: {
    red = red * 1.0;
    green = green * 1.0;
    blue = blue * 1.0;
    alpha = 1.0;
  };

  /**
    Restore preference domains from a directory of plist snapshots

    Accept a Nix path. For each named storage key, restore `<name>.plist` from
    that directory. Restoration deletes the destination domain before importing
    the snapshot, even if the storage metadata names an individual key. Snapshot
    files must contain the domain contents that should remain

    # Type

    ```
    snapshot :: Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.snapshot` usage example

    ```nix
    s.snapshot.encode { dock = s.domain "com.apple.dock"; } ./saved-dock
    ```

    :::
  */
  snapshot = {
    kind = "snapshot";
    type = lib.types.path;
    choices = [ ];
    examples = [ "/path/to/snapshot" ];
    encode =
      keys: directory: lib.mapAttrsToList (name: key: ops.restore key "${directory}/${name}.plist") keys;
    fromName = name: name;
  };

  /**
    Manage selected boolean entries in a dictionary preference

    Each named option is nullable, with null preserving the stored entry. Merge
    only non-null entries at execution time. Decode stored booleans and
    integers, treating false and zero as off

    # Inputs

    `entries`
    : Attribute set mapping option names to dictionary entry names

    # Type

    ```
    dictSwitches :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.dictSwitches` usage example

    ```nix
    s.dictSwitches { enabled = "Enabled"; showBadge = "ShowBadge"; }
    ```

    :::
  */
  dictSwitches = entries: {
    kind = "switches";
    decode =
      keys: get:
      let
        stored = readSingle keys get;
      in
      if lib.isAttrs stored then
        lib.mapAttrs (_: entry: stored.${entry} != false && stored.${entry} != 0) (
          lib.filterAttrs (
            _: entry: stored ? ${entry} && (lib.isBool stored.${entry} || lib.isInt stored.${entry})
          ) entries
        )
      else
        null;
    type = switchesType entries;
    choices = lib.attrNames entries;
    examples = [ (lib.mapAttrs (_: _: true) entries) ];
    encode =
      keys: value:
      let
        set = setSwitches entries value;
      in
      lib.optional (set != { }) (
        ops.mergeDict (single keys) (lib.mapAttrs' (name: on: lib.nameValuePair entries.${name} on) set)
      );
    fromName = builtins.fromJSON;
  };

  /**
    Manage selected strings in an array preference

    Each named switch is nullable. Null preserves membership. Modify only
    explicitly managed members, retaining other stored strings. The renderer
    requires a plain user domain, without host specificity or a `~/` path

    # Inputs

    `items`
    : Attribute set mapping switch names to stored strings

    `listedWhen`
    : Whether true means present in the array, defaulting to true

    # Type

    ```
    members :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.members` usage example

    ```nix
    s.members { items = { safari = "com.apple.Safari"; }; listedWhen = false; }
    ```

    :::
  */
  members =
    {
      items,
      listedWhen ? true,
    }:
    {
      kind = "switches";
      decode =
        keys: get:
        let
          stored = readSingle keys get;
          listed = if lib.isList stored then stored else [ ];
        in
        lib.mapAttrs (_: item: lib.elem item listed == listedWhen) items;
      type = switchesType items;
      choices = lib.attrNames items;
      examples = [ (lib.mapAttrs (_: _: true) items) ];
      encode =
        keys: value:
        let
          set = setSwitches items value;
        in
        lib.optional (set != { }) (
          ops.setMembers (single keys) (
            lib.mapAttrs' (name: on: lib.nameValuePair items.${name} (on == listedWhen)) set
          )
        );
      fromName = builtins.fromJSON;
    };

  /**
    Manage one string's membership in an array preference

    Use the same runtime restrictions as `members`, with a boolean option
    instead of a record of switches

    # Inputs

    `item`
    : String to add or remove

    `listedWhen`
    : Whether true means present in the array, defaulting to true

    # Type

    ```
    member :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.member` usage example

    ```nix
    s.member { item = "com.apple.Safari"; }
    ```

    :::
  */
  member =
    {
      item,
      listedWhen ? true,
    }:
    bool
    // {
      encode = keys: value: [ (ops.setMembers (single keys) { ${item} = value == listedWhen; }) ];
    };

  /**
    Manage selected bits in an integer preference, assuming zero when absent

    Each switch is nullable. Null preserves its current bits. Modify only
    managed masks at execution time. Equivalent to `flagsWhenAbsent 0`

    # Inputs

    `bits`
    : Attribute set mapping switch names to integer bit masks

    # Type

    ```
    flags :: AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.flags` usage example

    ```nix
    s.flags { first = 1; second = 2; }
    ```

    :::
  */
  flags = flagsWhenAbsent 0;

  /**
    Manage selected bits with an explicit fallback for an absent key

    Use the fallback both for current-value decoding and runtime updates. Retain
    unmanaged bits. Each switch is nullable, with null leaving its mask
    unmanaged. Masks may cover more than one bit

    # Inputs

    `absentValue`
    : Integer assumed when the key is absent

    `bits`
    : Attribute set mapping switch names to integer bit masks

    # Type

    ```
    flagsWhenAbsent :: Int -> AttrSet -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.flagsWhenAbsent` usage example

    ```nix
    s.flagsWhenAbsent 3 { first = 1; second = 2; }
    ```

    :::
  */
  flagsWhenAbsent = absentValue: bits: {
    kind = "flags";
    decode =
      keys: get:
      let
        stored = readSingle keys get;
        value = if stored == null then absentValue else stored;
      in
      if lib.isInt value then lib.mapAttrs (_: bit: builtins.bitAnd value bit != 0) bits else null;
    type = switchesType bits;
    choices = lib.attrNames bits;
    examples = [ (lib.mapAttrs (_: _: true) bits) ];
    encode =
      keys: value:
      let
        managed = lib.intersectAttrs (setSwitches bits value) bits;
        mask = bitSum (lib.attrValues managed);
        set = bitSum (lib.attrValues (lib.filterAttrs (name: _: value.${name}) managed));
      in
      lib.optional (mask != 0) (ops.writeFlags (single keys) mask set absentValue);
    fromName = builtins.fromJSON;
  };

  /**
    Manage one symbolic hotkey in a dictionary preference

    False disables the shortcut, true enables its existing binding, and a
    shortcut string enables it with new parameters. Merge only this hotkey's
    entry, retaining other hotkeys. Use `shortcuts.type` for string syntax

    # Inputs

    `id`
    : Symbolic hotkey identifier

    # Type

    ```
    hotKey :: Int -> Codec
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.hotKey` usage example

    ```nix
    s.hotKey 60
    ```

    :::
  */
  hotKey = id: {
    kind = "shortcut";
    decode =
      keys: get:
      let
        stored = readSingle keys get;
        entry = if lib.isAttrs stored then stored.${toString id} or null else null;
        enabled = entry.enabled or false;
        parameters = entry.value.parameters or null;
        keysShown = if parameters == null then null else shortcuts.fromHotKey parameters;
      in
      if !lib.isAttrs entry then
        null
      # macOS stores enabled as either CFBoolean or an integral CFNumber
      else if !(lib.isBool enabled || lib.isInt enabled) then
        null
      else if enabled == false || enabled == 0 then
        false
      else if keysShown == null then
        true
      else
        keysShown;
    type = lib.types.either lib.types.bool shortcuts.type;
    choices = [ ];
    examples = [
      false
      "⌘⇧S"
    ];
    encode = keys: choice: [
      (ops.mergeDict (single keys) {
        ${toString id} =
          if lib.isBool choice then
            { enabled = choice; }
          else
            {
              enabled = true;
              value = {
                type = "standard";
                parameters = shortcuts.hotKeyParameters choice;
              };
            };
      })
    ];
    fromName = name: if name == "true" || name == "false" then builtins.fromJSON name else name;
  };
in
{
  inherit
    absent
    bool
    inverted
    storedAs
    boolAs
    eachKey
    integerBool
    boolKeys
    inDict
    text
    strings
    number
    numberBetween
    enum
    enumDict
    rgb
    snapshot
    dictSwitches
    members
    member
    flags
    flagsWhenAbsent
    hotKey
    ;
}

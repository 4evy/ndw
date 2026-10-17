{
  lib,
  ops,
  behaviorsLib,
}:
let
  /**
    Wrap a setting constructor with shared defaults

    UI labels concatenate as lists. Other attributes use the entry's value when
    present, including `behaviors` and `relations`, which replace their
    defaults. Verification attributes merge one level deep. An explicit
    `verify = null` disables verification. `verify.open` replaces the inherited
    navigation path

    # Inputs

    `make`
    : Constructor to wrap

    `defaults`
    : Shared setting arguments

    `args`
    : Entry-specific arguments

    # Type

    ```
    sectionWith :: Constructor -> AttrSet -> AttrSet -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.sectionWith` usage example

    ```nix
    s.sectionWith s.setting { behaviors = [ (s.restarts "Dock") ]; } {
      ui = "Autohide";
      storage = s.user "com.apple.dock" "autohide";
      value = s.bool;
    }
    ```

    :::
  */
  sectionWith =
    make: defaults: args:
    make (
      defaults
      // args
      // {
        ui = lib.toList (defaults.ui or [ ]) ++ lib.toList (args.ui or [ ]);
      }
      // lib.optionalAttrs (defaults ? verify || args ? verify) {
        verify = lib.mapNullable (spec: (defaults.verify or { }) // spec) (args.verify or { });
      }
    );

  /**
    Create a setting constructor with shared UI and argument defaults

    Use `sectionWith setting` semantics, but require each bare setting to supply
    its own verification specification. Inherited verification context alone
    does not enable verification. Use `page` for bundled control constructors

    # Inputs

    `defaults`
    : Shared arguments, including a UI prefix and optional verification context

    `args`
    : Arguments accepted by `setting`

    # Type

    ```
    section :: AttrSet -> AttrSet -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.section` usage example

    ```nix
    s.section { ui = "Dock"; } {
      ui = "Autohide";
      storage = s.user "com.apple.dock" "autohide";
      value = s.bool;
    }
    ```

    :::
  */
  section = defaults: args: sectionWith setting defaults (args // { verify = args.verify or null; });

  /**
    Declare a typed setting with a storage plan and optional UI verification

    Accept one storage key or a record of keys, all in the same scope. Null is
    unmanaged. When allowed, `"unset"` deletes every key. The returned `option`
    has a null default. `plan value` encodes values without validating their
    type, so use the module system or `module.standalone` to validate external
    values

    Apply behaviors in list order after encoding. An `apply` function replaces
    encoded writes with commands for values other than `"unset"`. Key metadata
    still describes ownership and reads. Default behaviors finally clear stale
    host-specific copies of ordinary user keys

    The returned record also exposes `ui`, `keys`, `scope`, `codec`,
    `relations`, `description`, `reads`, `canUnset`, and normalized `verify`
    metadata

    # Inputs

    `ui`
    : UI label or list of labels

    `storage`
    : Storage key or attribute set of named storage keys

    `value`
    : Codec describing accepted values and their storage

    `behaviors`
    : Plan transformations, defaulting to `[]`

    `relations`
    : Dependency checks evaluated by `module.build`, defaulting to `[]`

    `apply`
    : Optional value-to-command function, returning a string or list of strings

    `verify`
    : Null by default, or a specification with `expect` mapping value names to
      control expectations. Optional fields include `pane`, `app`, `open`,
      `operate`, and `sideEffects`. Value names are parsed by the codec

    `reads`
    : Null by default, or `{ command, values?, parse? }`. The command is shell
      source. `values` maps codec value names to command output, while `parse`
      converts JSON output to a value. See `read.current`

    `description`
    : Additional option documentation, defaulting to an empty string

    `canUnset`
    : Whether `"unset"` may delete the keys. Defaults to true without `apply`
      and false with `apply`. Command backends must opt in explicitly

    # Type

    ```
    setting :: AttrSet -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.setting` usage example

    ```nix
    s.setting {
      ui = [ "Dock" "Autohide" ];
      storage = s.user "com.apple.dock" "autohide";
      value = s.bool;
      behaviors = [ (s.restarts "Dock") ];
    }
    ```

    :::
  */
  setting =
    {
      ui,
      storage,
      value,
      behaviors ? [ ],
      relations ? [ ],
      apply ? null,
      verify ? null,
      reads ? null,
      description ? "",
      canUnset ? apply == null,
    }:
    let
      keys = if storage._type or null == "storageKey" then { value = storage; } else storage;
      scopes = lib.unique (map (key: key.scope) (lib.attrValues keys));
      scope =
        if lib.length scopes == 1 then
          lib.head scopes
        else
          throw "setting ${lib.concatStringsSep " > " (lib.toList ui)} mixes user and system storage";

      encode =
        v: if canUnset && v == "unset" then map ops.delete (lib.attrValues keys) else value.encode keys v;

      # Run a command setter before restart behaviors and host-copy cleanup
      transforms =
        lib.optional (apply != null) (behaviorsLib.appliesThrough apply)
        ++ behaviors
        ++ behaviorsLib.defaults;
    in
    {
      _type = "setting";
      ui = lib.toList ui;
      inherit
        keys
        scope
        relations
        description
        reads
        canUnset
        ;
      codec = value;

      option = lib.mkOption {
        description = ''
          ${lib.concatStringsSep " > " (lib.toList ui)}

          ${description}

          Null leaves this setting unmanaged.${lib.optionalString canUnset ''
            Use "unset" to delete its stored preferences
          ''}
        '';
        default = null;
        type = lib.types.nullOr (
          if canUnset then lib.types.either value.type (lib.types.enum [ "unset" ]) else value.type
        );
      };

      plan =
        v:
        if v == null then
          [ ]
        else
          lib.foldl' (
            plan: behavior:
            behavior {
              inherit keys;
              value = v;
            } plan
          ) (encode v) transforms;

      verify = lib.mapNullable (
        spec:
        spec
        // {
          open = spec.open or [ ];
          operate = spec.operate or null;
          sideEffects = spec.sideEffects or null;
          expect = lib.mapAttrsToList (name: controls: {
            value = value.fromName name;
            inherit controls;
          }) spec.expect;
        }
      ) verify;
    };

  /**
    Construct a named family of settings

    Pass each member's arguments to the constructor with `name` set to its
    attribute name, overriding any `name` already present

    # Inputs

    `members`
    : Attribute set of argument sets

    `settings`
    : Constructor accepting the arguments and the injected `name`

    # Type

    ```
    family :: AttrSet -> (AttrSet -> Setting) -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.family` usage example

    ```nix
    s.family { autohide.ui = "Autohide"; } ({ name, ui }: s.setting {
      inherit ui;
      storage = s.user "com.apple.dock" name;
      value = s.bool;
    })
    ```

    :::
  */
  family = members: settings: lib.mapAttrs (name: args: settings (args // { inherit name; })) members;

  /**
    Recognize an attribute set tagged as a setting

    Check only the `_type` tag, without validating the record fields

    # Inputs

    `value`
    : Any Nix value

    # Type

    ```
    isSetting :: Any -> Bool
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.isSetting` usage example

    ```nix
    s.isSetting { _type = "setting"; }
    => true
    s.isSetting null
    => false
    ```

    :::
  */
  isSetting = value: lib.isAttrs value && value._type or null == "setting";
in
{
  inherit
    sectionWith
    section
    setting
    family
    isSetting
    ;
}

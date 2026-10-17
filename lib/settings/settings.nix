# Settings catalog and engine adapted from SushyDev/nix-plist-manager
# https://github.com/SushyDev/nix-plist-manager/commit/4ef635b8b2f4c88929ea7d1a8a941acbab5de719
# Copyright (c) 2025-2026 SushyDev, MIT license in ../../LICENSE
/**
  Declare macOS settings and turn configured values into activation scripts

  All helpers from storage, codecs, behaviors, relations, setting constructors,
  controls, and descriptions are exported directly as `lib.darwin.settings`. The
  engine helpers keep their namespaces: `module`, `render`, `read`, `ops`,
  `live`, `shows`, and `shortcuts`

  A `StorageKey` identifies a domain, key name, user or system scope, optional
  host specificity, and optional storage type. A single key becomes the `value`
  member of a setting's key record. A multi-key record names each key

  A `Codec` supplies `type`, `kind`, `choices`, `examples`, `fromName`, and
  `encode keys value`. Encoding returns a `Plan`, a list of operation records
  from `ops`. Some codecs also supply `decode keys get`, where `get` reads a
  stored key and returns null when absent. Wrappers that change storage remove
  an inherited decoder so current-value reads do not use the wrong mapping

  A `Setting` contains its UI path, keys, scope, codec, module option, and
  `plan value`. Null leaves the setting unmanaged. When `canUnset` is true, the
  string `"unset"` deletes its keys. Other values are encoded and passed through
  behaviors. A `Behavior` transforms a plan using `{ keys, value }`

  A `Constructor` accepts an attribute set of setting arguments and returns a
  `Setting`. Page constructors bind shared arguments before accepting an entry

  A `Relation` receives `{ path, value, get, planFor }` and returns diagnostic
  records, optionally with an implied plan. Dotted paths are relative to the
  settings catalog, such as `applications.systemSettings.appearance.appearance`,
  without the `system.settings` module prefix

  A `Catalog` is a nested attribute set whose leaves are settings.
  `module.optionTree` exposes their options, and `module.build` collects plans,
  warnings, and assertions. `standalone` checks values against the built-in
  catalog and returns separate user and system scripts. Generating a script does
  not execute it. Run user scripts in the intended user's session and system
  scripts as root

  Examples throughout the settings sources use `s = lib.darwin.settings` and
  `lib` for the Nixpkgs library

  # Examples
  :::{.example}
  ## `lib.darwin.settings` usage example

  ```nix
  let
    s = inputs.darwin.lib.darwin.settings;
    tree.hideDock = s.setting {
      ui = [ "Dock" "Automatically hide and show the Dock" ];
      storage = s.user "com.apple.dock" "autohide";
      value = s.bool;
      behaviors = [ (s.restarts "Dock") ];
    };
  in
  s.module.standalone { inherit tree; values.hideDock = true; }
  ```

  :::
*/
{ lib, settingsScripts }:
let
  ops = import ./ops.nix { };
  storage = import ./storage.nix { inherit lib; };
  shortcuts = import ./shortcuts.nix { inherit lib; };
  codecs = import ./codecs.nix { inherit lib ops shortcuts; };
  behaviorsLib = import ./behaviors.nix { inherit lib ops; };
  relations = import ./relations.nix { inherit lib; };
  core = import ./setting.nix { inherit lib ops behaviorsLib; };
  controls = import ./controls.nix {
    inherit
      lib
      codecs
      shows
      core
      ;
  };
  live = import ./live/live.nix { inherit lib settingsScripts; };
  render = import ./render.nix { inherit lib live; };
  module = import ./module.nix {
    inherit lib render;
    inherit (core) isSetting;
  };
  describe = import ./describe.nix { inherit lib render; };
  shows = import ./shows.nix { inherit lib; };
  read = import ./read.nix {
    inherit
      lib
      module
      render
      settingsScripts
      ;
  };
  result =
    storage
    // codecs
    // behaviorsLib
    // relations
    // core
    // controls
    // describe
    // {
      inherit
        ops
        render
        module
        live
        shortcuts
        shows
        read
        ;
      /**
        Expose the built-in tree of setting declarations

        Paths match the options below `system.settings`, without that prefix.
        Leaves are `Setting` records. Use `module.settingsIn` to enumerate them

        # Type

        ```
        catalog :: Catalog
        ```

        # Examples
        :::{.example}
        ## `lib.darwin.settings.catalog` usage example

        ```nix
        s.catalog.applications.finder.settings.advanced.showAllFilenameExtensions
        ```

        :::
      */
      catalog = import ../../modules/system/settings/catalog/catalog.nix {
        inherit lib;
        settingsLib = result;
      };
      /**
        Describe every built-in setting for documentation and discovery

        Return `describe` metadata with an additional dotted `option` path
        relative to the catalog root. Descriptions include generated example
        commands

        # Type

        ```
        optionIndex :: [AttrSet]
        ```

        # Examples
        :::{.example}
        ## `lib.darwin.settings.optionIndex` usage example

        ```nix
        map (entry: entry.option) s.optionIndex
        ```

        :::
      */
      optionIndex = map (
        leaf:
        {
          option = lib.concatStringsSep "." leaf.path;
        }
        // result.describe leaf.entry
      ) (module.settingsIn result.catalog);
      /**
        Generate a macOS collection script using the built-in catalog

        Accept the arguments of `read.collect`, with `tree` defaulting to
        `catalog`. Return shell source without running it

        # Inputs

        `args`
        : Collection arguments, optionally overriding the catalog tree

        # Type

        ```
        collect :: AttrSet -> String
        ```

        # Examples
        :::{.example}
        ## `lib.darwin.settings.collect` usage example

        ```nix
        s.collect { only = "applications.finder."; }
        ```

        :::
      */
      collect = args: read.collect ({ tree = result.catalog; } // args);
      /**
        Interpret collected state using the built-in catalog and recorded
        defaults

        Accept the arguments of `read.current`, with `tree` defaulting to
        `catalog` and `recorded` to the bundled macOS default values. This
        evaluates supplied state and does not read the running machine

        # Inputs

        `args`
        : Current-state arguments, usually including `collected` and `build`

        # Type

        ```
        current :: AttrSet -> AttrSet
        ```

        # Examples
        :::{.example}
        ## `lib.darwin.settings.current` usage example

        ```nix
        s.current { collected = {}; }
        ```

        :::
      */
      current =
        args:
        read.current (
          {
            tree = result.catalog;
            recorded = ../../modules/system/settings/defaults;
          }
          // args
        );
      /**
        Validate built-in catalog values and generate user and system scripts

        Throw on failed assertions and emit dependency warnings through
        `lib.warn`. Return `{ user, system }` containing Bash source strings.
        Values are relative to the catalog root, without the `system.settings`
        module prefix

        # Inputs

        `values`
        : Nested catalog values

        # Type

        ```
        standalone :: AttrSet -> { user :: String; system :: String; }
        ```

        # Examples
        :::{.example}
        ## `lib.darwin.settings.standalone` usage example

        ```nix
        s.standalone { applications.finder.settings.advanced.showAllFilenameExtensions = true; }
        ```

        :::
      */
      standalone =
        values:
        let
          built = module.standalone {
            tree = result.catalog;
            inherit values;
          };
          failed = map (assertion: assertion.message) (built.user.assertions ++ built.system.assertions);
        in
        if failed != [ ] then
          throw (lib.concatStringsSep "\n" failed)
        else
          lib.foldr lib.warn {
            user = built.user.script;
            system = built.system.script;
          } (built.user.warnings ++ built.system.warnings);
      /**
        Generate Bash source for one built-in catalog setting

        Validate through `standalone`, then concatenate nonempty user and system
        scripts. This does not add sudo or execute the command

        # Inputs

        `optionPath`
        : Dotted path relative to the catalog root

        `value`
        : Value to configure

        # Type

        ```
        commandFor :: String -> Any -> String
        ```

        # Examples
        :::{.example}
        ## `lib.darwin.settings.commandFor` usage example

        ```nix
        s.commandFor "applications.finder.settings.advanced.showAllFilenameExtensions" true
        ```

        :::
      */
      commandFor =
        optionPath: value:
        let
          scripts = result.standalone (lib.setAttrByPath (lib.splitString "." optionPath) value);
        in
        lib.concatStringsSep "\n" (
          lib.filter (script: script != "") [
            scripts.user
            scripts.system
          ]
        );
      /**
        Generate a Bash script applying built-in catalog values

        Validate through `standalone`. Place user commands first, then wrap any
        system commands in `/usr/bin/sudo /bin/bash -euc`. Run the generated
        script as the intended user in their macOS session, using Bash with
        failure handling

        # Inputs

        `values`
        : Nested catalog values

        # Type

        ```
        applyScript :: AttrSet -> String
        ```

        # Examples
        :::{.example}
        ## `lib.darwin.settings.applyScript` usage example

        ```nix
        s.applyScript { applications.finder.settings.advanced.showAllFilenameExtensions = true; }
        ```

        :::
      */
      applyScript =
        values:
        let
          scripts = result.standalone values;
        in
        lib.concatStringsSep "\n" (
          lib.filter (script: script != "") [
            scripts.user
            (lib.optionalString (
              scripts.system != ""
            ) "/usr/bin/sudo /bin/bash -euc ${lib.escapeShellArg scripts.system}")
          ]
        );
    };
in
result

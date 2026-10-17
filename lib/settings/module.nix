{
  lib,
  render,
  isSetting,
}:
let
  conflicts = import ./conflicts.nix { inherit lib; };
  /**
    Collect setting leaves from a nested catalog in attribute-name order

    Return `{ path, entry }` records. Stop descending at a setting and ignore
    other leaves. Paths are lists of attribute names relative to the tree

    # Inputs

    `tree`
    : Catalog tree

    # Type

    ```
    settingsIn :: Catalog -> [{ path :: [String]; entry :: Setting; }]
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.module.settingsIn` usage example

    ```nix
    s.module.settingsIn { example = s.catalog.applications.finder; }
    ```

    :::
  */
  settingsIn =
    tree:
    lib.filter (leaf: isSetting leaf.entry) (
      lib.mapAttrsToListRecursiveCond (_: value: !isSetting value) (path: entry: {
        inherit path entry;
      }) tree
    );

  inScope = scope: entry: scope == null || entry.scope == scope;

  /**
    Replace setting leaves with their module option declarations

    Include only settings in the requested scope. Null includes both scopes. The
    returned tree is suitable for a module's `options` attribute

    # Inputs

    `tree`
    : Catalog tree

    `scope`
    : Required scope selector, `"user"`, `"system"`, or null

    # Type

    ```
    optionTree :: { tree :: Catalog; scope :: String | Null; } -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.module.optionTree` usage example

    ```nix
    let
      evaluated = lib.evalModules {
        modules = [
          {
            options.settings = s.module.optionTree {
              tree = s.catalog;
              scope = "user";
            };
            config.settings.applications.finder.settings.advanced = {
              showAllFilenameExtensions = true;
            };
          }
        ];
      };
    in
    evaluated.config.settings.applications.finder.settings.advanced.showAllFilenameExtensions
    => true
    ```

    :::
  */
  optionTree =
    { tree, scope }:
    lib.updateManyAttrsByPath (map (leaf: {
      inherit (leaf) path;
      update = _: leaf.entry.option;
    }) (lib.filter (leaf: inScope scope leaf.entry) (settingsIn tree))) { };

  /**
    Build a plan, shell script, and diagnostics from configured settings

    Collect non-null values in scope. Skip relations for `"unset"`. Relations
    may append implied plans, and conflicting writes produce failed assertions.
    Return `{ plan, script, assertions, warnings }`. The caller must enforce
    assertions before executing the script. Values are not type-checked here, so
    use module evaluation or `module.standalone` first

    Suppressing warnings affects messages only, including when a relation also
    adds a plan. It does not suppress failed assertions or implied operations

    # Inputs

    `tree`
    : Catalog tree

    `values`
    : Evaluated values matching the catalog's nested shape

    `scope`
    : Required scope selector, `"user"`, `"system"`, or null

    `ignoreWarnings`
    : Diagnostic IDs or source setting paths to silence, defaulting to `[]`

    # Type

    ```
    build :: AttrSet -> { plan :: Plan; script :: String; assertions :: [AttrSet]; warnings :: [String]; }
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.module.build` usage example

    ```nix
    s.module.build {
      tree = s.catalog;
      values = {};
      scope = "user";
    }
    ```

    :::
  */
  build =
    {
      tree,
      values,
      scope,
      ignoreWarnings ? [ ],
    }:
    let
      get = path: lib.attrByPath path null values;
      getDotted = path: get (lib.splitString "." path);

      managed = lib.filter (leaf: inScope scope leaf.entry && get leaf.path != null) (settingsIn tree);

      planFor =
        path: value:
        let
          other = lib.attrByPath (lib.splitString "." path) null tree;
        in
        if isSetting other then other.plan value else throw "${path} isn't a setting";

      results = lib.concatMap (
        leaf:
        let
          value = get leaf.path;
          context = {
            inherit value planFor;
            path = lib.concatStringsSep "." leaf.path;
            get = getDotted;
          };
        in
        lib.optionals (value != "unset") (lib.concatMap (relation: relation context) leaf.entry.relations)
      ) managed;

      ofKind = kind: lib.filter (result: result.kind == kind) results;
      ignored =
        result:
        lib.elem result.id ignoreWarnings
        || lib.elem (lib.head (lib.splitString " -> " result.id)) ignoreWarnings;

      tagged = setting: map (step: step // { inherit setting; });
      plan =
        lib.concatMap (
          leaf: tagged (lib.concatStringsSep "." leaf.path) (leaf.entry.plan (get leaf.path))
        ) managed
        ++ lib.concatMap (result: tagged result.id (result.plan or [ ])) results;
    in
    {
      inherit plan;
      script = render.script plan;
      assertions =
        conflicts plan
        ++ map (result: {
          assertion = false;
          message = "darwin.settings: ${result.message}";
        }) (ofKind "assertion");
      warnings = map (
        result: "darwin.settings: ${result.message} (silence with ignoreWarnings = [ \"${result.id}\" ])"
      ) (lib.filter (result: !(ignored result)) (ofKind "warning"));
    };

  /**
    Validate values against a catalog and build separate user and system results

    Evaluate options through Nixpkgs' module system, then call `build` for each
    scope. Return `{ user, system }`, each with a plan, script, assertions, and
    warnings. Unlike `settings.standalone`, this lower-level helper accepts a
    custom tree and leaves assertion enforcement and warning emission to the
    caller

    # Inputs

    `tree`
    : Catalog tree

    `values`
    : Nested option values to validate

    `ignoreWarnings`
    : Warning IDs or source setting paths to silence, defaulting to `[]`

    # Type

    ```
    standalone :: AttrSet -> { user :: AttrSet; system :: AttrSet; }
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.module.standalone` usage example

    ```nix
    s.module.standalone { tree = s.catalog; values = {}; }
    ```

    :::
  */
  standalone =
    {
      tree,
      values,
      ignoreWarnings ? [ ],
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          {
            options.settings = optionTree {
              inherit tree;
              scope = null;
            };
          }
          { config.settings = values; }
        ];
      };
      buildScope =
        scope:
        build {
          inherit tree scope ignoreWarnings;
          values = evaluated.config.settings;
        };
    in
    {
      user = buildScope "user";
      system = buildScope "system";
    };
in
{
  inherit
    settingsIn
    optionTree
    build
    standalone
    ;
}

{ lib, render }:
let
  name =
    value:
    if lib.isAttrs value then
      "{ ${lib.concatMapAttrsStringSep "; " (k: v: "${k} = ${builtins.toJSON v}") value}; }"
    else if lib.isString value then
      value
    else
      builtins.toJSON value;

  storageKey =
    key:
    {
      inherit (key) domain byHost scope;
      key = key.name;
    }
    // lib.optionalAttrs (key.type != null) { inherit (key) type; };

  /**
    Describe a setting as metadata for documentation and tools

    Exported as `settings.describe`. Return UI `path`, module hint, option type,
    codec kind and choices, storage locations, example commands, verification
    metadata, description, example text, deletion support, optional read
    command, and optional numeric range. The module hint is `"darwin"` for
    system scope and `"home-manager"` for user scope. Example commands are
    generated, not run

    # Inputs

    `setting`
    : Setting record

    # Type

    ```
    describe :: Setting -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.describe` usage example

    ```nix
    s.describe s.catalog.applications.finder.settings.advanced.showAllFilenameExtensions
    ```

    :::
  */
  describeSetting = setting: {
    path = setting.ui;
    module = if setting.scope == "system" then "darwin" else "home-manager";
    type = setting.option.type.description;
    kind = setting.codec.kind;
    choices = setting.codec.choices;
    storage = lib.mapAttrsToList (as: key: storageKey key // { inherit as; }) setting.keys;
    commands = lib.genAttrs' (setting.codec.examples ++ lib.optional setting.canUnset "unset") (
      value: lib.nameValuePair (name value) (render.script (setting.plan value))
    );
    verify = setting.verify;
    description = setting.option.description or "";
    example = lib.generators.toPretty { } (lib.head setting.codec.examples);
    inherit (setting) canUnset;
    reads = lib.mapNullable (reads: { inherit (reads) command; }) setting.reads;
    range =
      if setting.codec ? min then
        {
          inherit (setting.codec) min max;
          unit = setting.codec.unit or null;
        }
      else
        null;
  };
in
{
  describe = describeSetting;
}

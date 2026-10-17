{ lib }:
let
  plist = import ../plist/plist.nix { inherit lib; };
  # Retain toPlist's omission of nulls and module metadata, including in lists
  valueForPlist =
    value:
    if builtins.isAttrs value then
      lib.attrsets.mapAttrs (_: valueForPlist) (
        lib.attrsets.filterAttrs (name: value: name != "_module" && value != null) value
      )
    else if builtins.isList value then
      map valueForPlist (builtins.filter (value: value != null) value)
    else if builtins.isPath value then
      toString value
    else
      value;
in
{
  domains = import ./domains.nix { inherit lib; };

  /**
    Generate argument lists for writing macOS preference domains

    Domains and keys are emitted in attribute-name order. Keys with null values
    are omitted. Each remaining value is serialized as an XML property list,
    preserving arrays, dictionaries, float precision, and XML escaping. Null
    entries and `_module` dictionary keys are omitted as in Nixpkgs' plist
    generator. These commands update individual keys without replacing other
    preferences in a domain

    Pass the result to `lib.darwin.shell.commandLines` or map
    `lib.darwin.shell.asUser user` over it. This function generates commands and
    does not execute them

    # Inputs

    `currentHost`
    : Whether to write host-specific preferences, defaulting to `false`

    `domains`
    : Attribute set mapping preference domains to attribute sets of plist values

    # Type

    ```
    commands :: { currentHost? :: Bool; } -> AttrSet -> [[String]]
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.defaults.commands` usage example

    ```nix
    lib.darwin.shell.commandLines (commands {} {
      "com.apple.dock" = { autohide = true; tilesize = 48; };
    })
    commands { currentHost = true; } {
      "com.apple.controlcenter".BatteryShowPercentage = true;
    }
    ```

    :::
  */
  commands =
    {
      currentHost ? false,
    }:
    domains:
    lib.lists.concatLists (
      lib.attrsets.mapAttrsToList (
        domain: values:
        lib.attrsets.mapAttrsToList (
          key: value:
          [ "/usr/bin/defaults" ]
          ++ lib.lists.optional currentHost "-currentHost"
          ++ [
            "write"
            domain
            key
            (plist.document (valueForPlist value))
          ]
        ) (lib.attrsets.filterAttrs (_: value: value != null) values)
      ) domains
    );
}

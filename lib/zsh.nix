{ lib }:
let
  inherit (import ./types.nix { inherit lib; }) shellValue;
  inherit (import ./shell.nix { inherit lib; }) commandLines;
  scalar =
    value:
    assert lib.asserts.assertMsg (shellValue.check value)
      "darwin.zsh.mkZstyles: expected a string, path, number, or boolean";
    if builtins.isBool value then
      lib.trivial.boolToYesNo value
    else if builtins.isPath value then
      value
    else if builtins.isFloat value then
      lib.strings.floatToString value
    else
      toString value;
in
{
  /**
    Render Zsh style declarations from contexts mapped to style attribute sets

    Contexts and style names are emitted in attribute-name order. Omit null
    values, empty lists, and empty attribute sets. Scalars become one argument,
    lists become multiple arguments, and attribute sets become alternating
    name/value arguments in attribute-name order. Booleans become `yes` or `no`

    All arguments are escaped literally, including dollar signs and context
    patterns. The `-` marker keeps leading dashes in contexts literal. Local
    paths are copied to the store, and string context is retained. No
    trailing newline is added. Use separate calls when declarations require
    a different order

    # Inputs

    `contexts`
    : Attribute sets of styles keyed by Zsh context patterns. Values may be
      null, shell scalars, lists of scalars, or attribute sets of scalars

    # Type

    ```
    mkZstyles :: { [String] :: { [String] :: Any; }; } -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.zsh.mkZstyles` usage example

    ```nix
    mkZstyles {
      ":completion:*" = { menu = true; matcher-list = [ "m:{a-z}={A-Z}" ]; };
    }
    => "zstyle - ':completion:*' matcher-list 'm:{a-z}={A-Z}'\nzstyle - ':completion:*' menu yes"
    ```

    :::
  */
  mkZstyles =
    contexts:
    commandLines (
      lib.lists.concatLists (
        lib.attrsets.mapAttrsToList (
          context: styles:
          lib.attrsets.mapAttrsToList (
            name: value:
            [
              "zstyle"
              "-"
              context
              name
            ]
            ++ (
              if builtins.isList value then
                map scalar value
              else if builtins.isAttrs value then
                lib.lists.concatLists (
                  lib.attrsets.mapAttrsToList (key: item: [
                    key
                    (scalar item)
                  ]) value
                )
              else
                [ (scalar value) ]
            )
          ) (lib.attrsets.filterAttrs (_: value: value != null && value != [ ] && value != { }) styles)
        ) contexts
      )
    );
}

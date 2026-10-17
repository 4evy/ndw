{ lib }:
let
  /**
    Module option type for values accepted by `lib.darwin.shell.doubleQuote`

    Accept strings, paths, integers, floats, and booleans. Null values are not
    accepted by this type

    # Type

    ```
    shellValue :: OptionType
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.types.shellValue` usage example

    ```nix
    shellValue.check true
    => true
    shellValue.check null
    => false
    ```

    :::
  */
  shellValue = lib.types.oneOf (
    lib.attrsets.attrVals [
      "str"
      "path"
      "int"
      "float"
      "bool"
    ] lib.types
  );
in
{
  inherit shellValue;

  /**
    Module option type for shell variables with POSIX names and nullable
    `shellValue` values

    Keep values lazy so module definitions may refer to other variables. Null
    values are accepted for omission by `lib.darwin.shell.exportAll`. All
    attribute names must be valid, including those with null values

    # Type

    ```
    shellVariables :: OptionType
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.types.shellVariables` usage example

    ```nix
    options.session.variables = lib.options.mkOption {
      type = shellVariables;
      default = {};
    };
    ```

    :::
  */
  shellVariables = lib.types.addCheck (lib.types.lazyAttrsOf (lib.types.nullOr shellValue)) (
    values: lib.lists.all lib.strings.isValidPosixName (builtins.attrNames values)
  );
}

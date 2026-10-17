{ lib }:
let
  /**
    Declare a typed module option with an explicit default

    This sets the option's fallback value, with the same merge behavior as
    `lib.options.mkOption`. It does not set a definition's priority like
    `lib.modules.mkDefault`. Extend the result with `//` for metadata such as
    `example`, `defaultText`, or `internal`

    # Inputs

    `type`
    : Option type used for checking and merging values

    `default`
    : Fallback value when the option has no definitions

    `description`
    : Description passed unchanged to `lib.options.mkOption`

    # Type

    ```
    mkDefaultOption :: OptionType -> Any -> String -> Option
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.options.mkDefaultOption` usage example

    ```nix
    options.extra.packages = mkDefaultOption (lib.types.listOf lib.types.package)
      [] "Additional packages to install";
    options.retries = mkDefaultOption lib.types.int 3 "Retry attempts" // {
      example = 5;
    };
    ```

    :::
  */
  mkDefaultOption =
    type: default: description:
    lib.options.mkOption {
      inherit type default description;
    };
in
{
  inherit mkDefaultOption;

  /**
    Declare a nullable module option with a default of `null`

    The supplied type describes non-null values, and the description is passed
    unchanged to `lib.options.mkOption`

    # Inputs

    `type`
    : Option type for non-null values

    `description`
    : Description of the option

    # Type

    ```
    mkNullableOption :: OptionType -> String -> Option
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.options.mkNullableOption` usage example

    ```nix
    options.launcher.name = mkNullableOption lib.types.str "Launcher name";
    # Defaults to null and accepts string values
    ```

    :::
  */
  mkNullableOption = type: mkDefaultOption (lib.types.nullOr type) null;
}

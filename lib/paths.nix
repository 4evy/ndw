{ lib }:
let
  /**
    Test whether a string is a single file name

    Reject the empty string, `.` and `..`, and names containing `/`. This does
    not check whether the file exists or impose other filesystem restrictions on
    the name

    # Inputs

    `name`
    : File name to check

    # Type

    ```
    isFileName :: String -> Bool
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.paths.isFileName` usage example

    ```nix
    isFileName "zshrc"
    => true
    isFileName "shell/zshrc"
    => false
    isFileName ".."
    => false
    ```

    :::
  */
  isFileName = name: isRelativeFile name && !lib.strings.hasInfix "/" name;

  /**
    Test whether a string is a relative file path without empty, `.` or `..`
    components

    Reject absolute paths, repeated separators, and trailing separators. The
    filesystem is not accessed

    # Inputs

    `name`
    : Relative file path to check

    # Type

    ```
    isRelativeFile :: String -> Bool
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.paths.isRelativeFile` usage example

    ```nix
    isRelativeFile "shell/zshrc"
    => true
    isRelativeFile "../zshrc"
    => false
    isRelativeFile "shell//zshrc"
    => false
    isRelativeFile "/etc/zshrc"
    => false
    ```

    :::
  */
  isRelativeFile =
    name:
    lib.path.subpath.isValid name && name != "." && lib.path.subpath.normalise name == "./${name}";
in
{
  inherit isFileName isRelativeFile;
}

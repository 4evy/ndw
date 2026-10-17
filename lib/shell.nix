{ lib }:
let
  inherit (import ./types.nix { inherit lib; }) shellValue;

  /**
    Convert a shell value to a string and enclose it in shell double quotes

    Accept strings, paths, integers, floats, and booleans. Paths are copied to
    the store and retain their string context. Booleans become `"true"` or
    `"false"`. Float conversion warns if Nix loses precision

    Escape backslashes, double quotes, and backticks while preserving dollar
    expansion, including command substitution. The value must therefore be
    trusted shell input. Use `lib.strings.escapeShellArg` for literal arguments

    # Inputs

    `value`
    : Value accepted by `lib.darwin.types.shellValue`

    # Type

    ```
    doubleQuote :: (String | Path | Int | Float | Bool) -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.shell.doubleQuote` usage example

    ```nix
    doubleQuote "$HOME/bin"
    => ''"$HOME/bin"''
    doubleQuote false
    => ''"false"''
    ```

    :::
  */
  doubleQuote =
    value:
    assert lib.asserts.assertMsg (shellValue.check value)
      "darwin.shell.doubleQuote: expected a string, path, number, or boolean";
    let
      # Interpolation copies Nix paths to the store and retains their context
      string =
        if builtins.isPath value then
          "${value}"
        else if builtins.isBool value then
          lib.trivial.boolToString value
        else if builtins.isFloat value then
          lib.strings.floatToString value
        else
          toString value;
    in
    ''"${lib.strings.escape [ "\\" "\"" "`" ] string}"'';

  /**
    Generate shell commands that print a literal message to standard error with
    a trailing newline and exit with status 2

    Exit even if writing the diagnostic fails. This function does not add an
    `error: ` prefix

    # Inputs

    `message`
    : Literal diagnostic to print

    # Type

    ```
    fail :: String -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.shell.fail` usage example

    ```nix
    ''
      if [[ $# -eq 0 ]]; then
        ${fail "usage: example NAME"}
      fi
    ''
    ```

    :::
  */
  fail = message: ''
    ${
      lib.strings.escapeShellArgs [
        "printf"
        "%s\\n"
        message
      ]
    } >&2 || :
    exit 2
  '';

  /**
    Generate shell commands that find an existing Nix installation

    Prefer the default installation and the caller's PATH, then search
    `nixPath`. Search for executable files rather than shell functions, then
    resolve the executable and put its directory first in PATH so sibling
    tools such as `nix-env` come from the same installation. Require GNU
    coreutils in PATH and exit with status 2 if no Nix client is found

    Default NIX_REMOTE to daemon while preserving an explicit override

    Set the Bash array `nix_command` to invoke Nix with the CLI and flakes
    features enabled for this command, including on upstream Nix installations

    # Inputs

    `nixPath`
    : Trusted shell search path, with dollar expansion preserved

    # Type

    ```
    nixEnvironment :: String -> String
    ```
  */
  nixEnvironment = nixPath: ''
    export NIX_REMOTE=''${NIX_REMOTE:-daemon}
    # Keep using the existing Nix installation rather than managing a second one
    export PATH="/nix/var/nix/profiles/default/bin:$PATH"
    if ! nix_bin=$(type -P nix) \
      && ! nix_bin=$(PATH=${doubleQuote nixPath} type -P nix); then
      ${fail "error: cannot find an existing Nix installation"}
    fi
    nix_bin=$(readlink --canonicalize-existing -- "$nix_bin")
    PATH="$(dirname -- "$nix_bin"):$PATH"
    export PATH
    nix_command=("$nix_bin" --extra-experimental-features 'nix-command flakes')
  '';

  /**
    Render literal shell commands in list order, separated by newlines

    Each command is an argument list escaped with
    `lib.strings.escapeShellArgs`. Local paths are copied to the store, and
    string context is retained. Shell expansion and operators are treated
    literally. Empty argument lists are omitted, and no trailing newline
    is added

    # Inputs

    `commands`
    : List of argument lists, each starting with an executable or shell builtin

    # Type

    ```
    commandLines :: [[String | Path]] -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.shell.commandLines` usage example

    ```nix
    commandLines [ [ "printf" "%s" "$HOME" ] [] [ "echo" "done" ] ]
    => "printf %s '$HOME'\necho done"
    ```

    :::
  */
  commandLines =
    commands:
    lib.strings.concatMapStringsSep "\n" (
      args:
      lib.strings.escapeShellArgs (
        # Older Nixpkgs escapers stringify local paths without copying them
        map (arg: if builtins.isPath arg && !lib.strings.isStorePath arg then "${arg}" else arg) args
      )
    ) (lib.lists.filter (args: args != [ ]) commands);

  /**
    Generate a command that runs in a macOS user's launchd session

    Resolve the user's UID with `/usr/bin/id` at runtime, enter their launchd
    bootstrap context, and use noninteractive sudo to switch identity and set
    HOME. Arguments are escaped literally, with string context preserved. The
    caller must have permission to run launchctl and sudo as that user

    # Inputs

    `user`
    : Nonempty account name, resolved on the machine running the command

    `args`
    : Nonempty argument list starting with the command to execute

    # Type

    ```
    asUser :: String -> [String | Path] -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.shell.asUser` usage example

    ```nix
    asUser "evy" [ "/usr/bin/defaults" "read" "com.apple.dock" "autohide" ]
    ```

    :::
  */
  asUser =
    user: args:
    assert lib.asserts.assertMsg (
      builtins.isString user && user != ""
    ) "darwin.shell.asUser: expected a nonempty account name";
    assert lib.asserts.assertMsg (
      args != [ ]
    ) "darwin.shell.asUser: expected a nonempty command argument list";
    let
      command = args: commandLines [ args ];
    in
    ''/bin/launchctl asuser "$(${
      command [
        "/usr/bin/id"
        "-u"
        "--"
        user
      ]
    })" ${
      command (
        [
          "/usr/bin/sudo"
          "--non-interactive"
          "--set-home"
          "--user=${user}"
          "--"
        ]
        ++ args
      )
    }'';

  /**
    Generate a shell conditional that prints an error and exits with status 2
    when its condition succeeds

    The condition is inserted as shell code. The message is passed literally to
    `fail` with an `error: ` prefix

    # Inputs

    `condition`
    : Shell command or expression whose zero exit status triggers the error

    `message`
    : Literal diagnostic without the `error: ` prefix

    # Type

    ```
    failIf :: String -> String -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.shell.failIf` usage example

    ```nix
    ''
      ${failIf "[[ $# -eq 0 ]]" "expected an argument"}
      printf '%s\n' "$1"
    ''
    ```

    :::
  */
  failIf = condition: message: ''
    if ${condition}; then
      ${fail "error: ${message}"}
    fi
  '';

  /**
    Generate shell alias declarations in attribute-name order, separated by
    newlines

    Flags, names, and values are escaped as literal shell arguments. Names must
    be nonempty and must not contain `=`. Values must be strings. An empty
    attribute set produces an empty string, and no trailing newline is added

    # Inputs

    `flags`
    : List of string flags passed to `alias` before `--`, such as `[]` for
      regular aliases or `[ "-g" ]` for Zsh global aliases

    `aliases`
    : Attribute set mapping alias names to their definitions

    # Type

    ```
    mkAliases :: [String] -> { [String] :: String; } -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.shell.mkAliases` usage example

    ```nix
    mkAliases [] { ll = "ls -l"; }
    => "alias -- 'll=ls -l'"
    mkAliases [ "-g" ] { G = "| grep"; }
    => "alias -g -- 'G=| grep'"
    ```

    :::
  */
  mkAliases =
    flags:
    assert lib.asserts.assertMsg (
      builtins.isList flags && lib.lists.all builtins.isString flags
    ) "darwin.shell.mkAliases: flags must be a list of strings";
    lib.strings.concatMapAttrsStringSep "\n" (
      name: value:
      assert lib.asserts.assertMsg (
        name != "" && !lib.strings.hasInfix "=" name
      ) "darwin.shell.mkAliases: alias names must be nonempty and must not contain '='";
      assert lib.asserts.assertMsg (builtins.isString value)
        "darwin.shell.mkAliases: alias ${lib.strings.escapeNixString name} must have a string value";
      lib.strings.escapeShellArgs (
        [ "alias" ]
        ++ flags
        ++ [
          "--"
          "${name}=${value}"
        ]
      )
    );

  /**
    Generate shell exports in attribute-name order, separated by newlines

    Omit null values and quote the remaining values with `doubleQuote`, so
    dollar expansion remains active. Booleans become `"true"` or `"false"`. No
    trailing newline is added

    # Inputs

    `variables`
    : Attribute set of trusted shell values keyed by POSIX shell variable names.
      Null entries are omitted before validating names. Non-null entries must
      have valid names and values accepted by `lib.darwin.types.shellValue`

    # Type

    ```
    exportAll :: {
      [String] :: String | Path | Int | Float | Bool | Null;
    } -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.shell.exportAll` usage example

    ```nix
    exportAll { ENABLED = true; OMIT = null; }
    => ''export ENABLED="true"''
    exportAll { PATH = "$HOME/bin"; }
    => ''export PATH="$HOME/bin"''
    ```

    :::
  */
  exportAll =
    variables:
    lib.strings.concatMapAttrsStringSep "\n" (
      name: value:
      assert lib.asserts.assertMsg (lib.strings.isValidPosixName name)
        "darwin.shell.exportAll: ${lib.strings.escapeNixString name} is not a valid shell variable name";
      builtins.addErrorContext "while exporting shell variable ${lib.strings.escapeNixString name}" "export ${name}=${doubleQuote value}"

    ) (lib.attrsets.filterAttrs (_: value: value != null) variables);
in
{
  inherit
    doubleQuote
    fail
    nixEnvironment
    commandLines
    asUser
    failIf
    mkAliases
    exportAll
    ;
}

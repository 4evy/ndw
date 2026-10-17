{ lib, settingsScripts }:
let
  q = lib.escapeShellArg;
  preferences = import ./preferences.nix { inherit lib; };
  # JXA is reserved for framework calls that have no command-line interface
  script =
    name: args:
    "/usr/bin/osascript -l JavaScript ${settingsScripts}/live/${name}.js ${lib.escapeShellArgs args}";
  quietly = name: args: "${script name args} >/dev/null";

in
{
  /**
    Generate a command selecting automatic, light, or dark appearance

    Use the native appearance helper. If it reports a deferred change, write the
    corresponding global preferences as a fallback

    Evaluation returns shell source. Execution requires macOS and the intended
    user or root context

    # Inputs

    `automatic`
    : Whether to follow automatic appearance

    `dark`
    : Manual dark-mode choice, defaulting to false

    # Type

    ```
    appearance :: { automatic :: Bool; dark? :: Bool; } -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.appearance` usage example

    ```nix
    s.live.appearance { automatic = false; dark = true; }
    ```

    :::
  */
  appearance =
    {
      automatic,
      dark ? false,
    }:
    "/bin/bash -euc "
    + q ''
      result=$(${
        script "appearance" (
          map lib.boolToString [
            automatic
            dark
          ]
        )
      })
      if [ "$result" = deferred ]; then
        ${
          if automatic then
            ''
              /usr/bin/defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true
            ''
          else
            ''
              /usr/bin/defaults delete -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || true
              ${
                if dark then
                  ''
                    /usr/bin/defaults write -g AppleInterfaceStyle Dark
                  ''
                else
                  ''
                    /usr/bin/defaults delete -g AppleInterfaceStyle 2>/dev/null || true
                  ''
              }
            ''
        }
      fi
    '';

  /**
    Generate a command invoking a CoreBrightness client method

    Discard standard output. The runtime helper accepts
    `CBTrueToneClient.setEnabled`, `CBBlueLightClient.setMode`, and
    `CBBlueLightClient.setStrengthCommit`, with one boolean, one number, and a
    number plus boolean respectively

    Evaluation returns shell source. Execution requires macOS and the intended
    user or root context

    # Inputs

    `client`
    : Native client class name

    `method`
    : Method selector used by the helper

    `arguments`
    : Boolean, numeric, or string arguments

    # Type

    ```
    coreBrightness :: String -> String -> [Any] -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.coreBrightness` usage example

    ```nix
    s.live.coreBrightness "CBTrueToneClient" "setEnabled" [ true ]
    ```

    :::
  */
  coreBrightness =
    client: method: arguments:
    quietly "brightness" (
      [
        client
        method
      ]
      ++ map (
        value:
        if lib.isBool value then
          lib.boolToString value
        else if lib.isFloat value then
          builtins.toJSON value
        else
          toString value
      ) arguments
    );

  /**
    Generate a command setting the recent-items count through the native helper

    Evaluation returns shell source. Execution requires macOS and the intended
    user or root context

    # Inputs

    `amount`
    : Nonnegative item count, validated by the runtime helper

    # Type

    ```
    recentItems :: Int -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.recentItems` usage example

    ```nix
    s.live.recentItems 10
    ```

    :::
  */
  recentItems = amount: quietly "recent" [ (toString amount) ];

  /**
    Generate a command replacing enabled input sources

    Pass input source identifiers as literal arguments to the native helper.
    Require at least one installed keyboard input source at execution time

    Evaluation returns shell source. Execution requires macOS and the intended
    user or root context

    # Inputs

    `ids`
    : Nonempty list of installed input source identifiers

    # Type

    ```
    inputSources :: [String] -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.inputSources` usage example

    ```nix
    s.live.inputSources [ "com.apple.keylayout.US" ]
    ```

    :::
  */
  inputSources = ids: quietly "input" ([ "set" ] ++ ids);
  /**
    Generate a command listing enabled input source identifiers

    The runtime helper prints a JSON array

    Evaluation returns shell source. Execution requires macOS and the intended
    user or root context

    # Type

    ```
    enabledInputSources :: String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.enabledInputSources` usage example

    ```nix
    s.live.enabledInputSources
    ```

    :::
  */
  enabledInputSources = script "input" [ "list" ];

  inherit (preferences) setMembers mergeDict;

  /**
    Generate a command updating WallpaperAgent's plist store

    Accept `all` for one choice on every display and Space, or `spaces` mapping
    Mission Control Desktop numbers to choices. Each choice supplies `provider`,
    `configuration` (a dictionary or null), and `options` (a dictionary), with
    an optional Photos `album` name or UUID. Desktop numbering starts at 1 on
    each display. A choice for a missing Desktop produces a runtime warning

    An `all` choice resets per-display and per-Space overrides. A `spaces`
    choice preserves unspecified Desktops' previous choices or the existing
    fallback. Replace the store file atomically. This helper does not download
    wallpaper assets or restart WallpaperAgent. The catalog composes those
    operations

    Evaluation generates shell source and store files. Run the command in the
    intended user's macOS session. Resolving a Photos album name requires access
    to that user's Photos library

    # Inputs

    `wanted`
    : Attribute set with optional `all` and `spaces` choices

    # Type

    ```
    wallpaper :: AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.wallpaper` usage example

    ```nix
    s.live.wallpaper {
      all = {
        provider = "com.apple.wallpaper.choice.color";
        configuration = {
          type = "systemColor";
          systemColor.plum = {};
        };
        options = {};
      };
    }
    ```

    :::
  */
  wallpaper = import ./wallpaper.nix { inherit lib settingsScripts; };

  /**
    Generate a command reading one value from `pmset -g custom`

    Insert `source` and `key` into an awk program. Use trusted constant names,
    such as `"Battery Power"` and `"displaysleep"`

    Evaluation returns shell source. Execution requires macOS and the intended
    user or root context

    # Inputs

    `source`
    : Power-source section name without the trailing colon

    `key`
    : Power-management key

    # Type

    ```
    pmsetValue :: String -> String -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.pmsetValue` usage example

    ```nix
    s.live.pmsetValue "Battery Power" "displaysleep"
    ```

    :::
  */
  pmsetValue =
    source: key:
    "/usr/bin/pmset -g custom | /usr/bin/awk ${q "$0 == \"${source}:\" { found = 1; next } /^[^ ]/ { found = 0 } found && $1 == \"${key}\" { print $2 }"}";
}

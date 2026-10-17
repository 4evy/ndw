{ lib }:
let
  /**
    Describe a preference location without reading or writing it

    The record is metadata for codecs, plans, and readers. No field validation
    or filesystem access occurs here

    # Inputs

    `domain`
    : Preference domain identifier or plist path

    `name`
    : Preference key name, or null for a whole-domain snapshot

    `scope`
    : `"user"` by default, or `"system"` for root-owned preferences

    `byHost`
    : Whether to use current-host preferences, defaulting to false

    `type`
    : Optional `defaults` storage type such as `"int"` or `"float"`, defaulting
      to null for inference from the encoded value

    # Type

    ```
    mkKey :: AttrSet -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.mkKey` usage example

    ```nix
    s.mkKey { domain = "com.apple.dock"; name = "tilesize"; type = "float"; }
    ```

    :::
  */
  mkKey =
    {
      domain,
      name,
      scope ? "user",
      byHost ? false,
      type ? null,
    }:
    {
      _type = "storageKey";
      inherit
        domain
        name
        scope
        byHost
        type
        ;
    };

  /**
    Recognize a storage-key record by its `_type` tag

    This does not validate the other fields

    # Inputs

    `value`
    : Any Nix value

    # Type

    ```
    isKey :: Any -> Bool
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.isKey` usage example

    ```nix
    s.isKey (s.user "com.apple.dock" "autohide")
    => true
    ```

    :::
  */
  isKey = value: lib.isAttrs value && value._type or null == "storageKey";

  /**
    Describe a key in the current user's preference domain

    # Inputs

    `domain`
    : Preference domain identifier or user plist path

    `name`
    : Preference key name

    # Type

    ```
    user :: String -> String -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.user` usage example

    ```nix
    s.user "com.apple.dock" "autohide"
    ```

    :::
  */
  user = domain: name: mkKey { inherit domain name; };

  /**
    Describe a whole user preference domain

    Set the key name to null. Use this with `snapshot`, which restores the whole
    domain rather than an individual key

    # Inputs

    `name`
    : Preference domain identifier

    # Type

    ```
    domain :: String -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.domain` usage example

    ```nix
    s.domain "com.apple.finder"
    ```

    :::
  */
  domain =
    name:
    mkKey {
      domain = name;
      name = null;
    };

  /**
    Describe a key in the user's `NSGlobalDomain` preferences

    # Inputs

    `name`
    : Global preference key name

    # Type

    ```
    global :: String -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.global` usage example

    ```nix
    s.global "AppleShowAllExtensions"
    ```

    :::
  */
  global = name: user "NSGlobalDomain" name;

  /**
    Describe a system preference key

    The renderer resolves domain identifiers under `/Library/Preferences`.
    Absolute domain paths are used as supplied

    # Inputs

    `domain`
    : Preference domain identifier or absolute plist path

    `name`
    : Preference key name

    # Type

    ```
    system :: String -> String -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.system` usage example

    ```nix
    s.system "com.apple.loginwindow" "GuestEnabled"
    ```

    :::
  */
  system =
    domain: name:
    mkKey {
      inherit domain name;
      scope = "system";
    };

  /**
    Describe a whole system plist file for snapshot restoration

    # Inputs

    `path`
    : Absolute plist path

    # Type

    ```
    file :: String -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.file` usage example

    ```nix
    s.file "/Library/Preferences/com.apple.loginwindow.plist"
    ```

    :::
  */
  file =
    path:
    mkKey {
      domain = path;
      name = null;
      scope = "system";
    };

  /**
    Mark a storage key as host-specific

    Preserve its other attributes

    # Inputs

    `key`
    : Storage key to modify

    # Type

    ```
    byHost :: StorageKey -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.byHost` usage example

    ```nix
    s.byHost (s.user "com.apple.controlcenter" "BatteryShowPercentage")
    ```

    :::
  */
  byHost = key: key // { byHost = true; };

  /**
    Override the `defaults` storage type of a key

    The codec still controls the accepted Nix values

    # Inputs

    `type`
    : Storage type flag without its leading dash, such as `"float"`

    `key`
    : Storage key to modify

    # Type

    ```
    stored :: String -> StorageKey -> StorageKey
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.stored` usage example

    ```nix
    s.stored "float" (s.user "com.apple.dock" "tilesize")
    ```

    :::
  */
  stored = type: key: key // { inherit type; };
in
{
  inherit
    mkKey
    isKey
    user
    domain
    global
    system
    file
    byHost
    stored
    ;
}

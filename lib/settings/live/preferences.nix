{ lib }:
let
  q = lib.escapeShellArg;
  inherit (import ../plist.nix { inherit lib; }) xml;
  keyPath = name: lib.replaceStrings [ "." ] [ "\\." ] name;
  dictionary = path: ''
    if [ "$(/usr/bin/plutil -type ${q path} "$work/updated.plist" 2>/dev/null)" != dictionary ]; then
      /usr/bin/plutil -replace ${q path} -dictionary "$work/updated.plist"
    fi
  '';
  merge =
    prefix: entries:
    lib.concatStrings (
      lib.mapAttrsToList (
        name: value:
        let
          path = "${prefix}.${keyPath name}";
        in
        if lib.isAttrs value then
          dictionary path + merge path value
        else
          ''
            /usr/bin/plutil -replace ${q path} -xml ${q (xml value)} "$work/updated.plist"
          ''
      ) entries
    );
  update =
    kind: domain: key: edits:
    let
      path = keyPath key;
    in
    "/bin/bash -euc "
    + q ''
      work=$(/usr/bin/mktemp -d)
      trap '/bin/rm -rf "$work"' EXIT
      /usr/bin/plutil -create xml1 "$work/updated.plist"
      # Import only the changed key so unrelated preferences are preserved
      if /usr/bin/defaults export ${q domain} "$work/exported.plist" 2>/dev/null; then
        if [ "$(/usr/bin/plutil -type ${q path} "$work/exported.plist" 2>/dev/null)" = ${kind} ]; then
          stored=$(/usr/bin/plutil -extract ${q path} xml1 -o - "$work/exported.plist")
          /usr/bin/plutil -replace ${q path} -xml "$stored" "$work/updated.plist"
        fi
      fi
      ${edits path}
      /usr/bin/defaults import ${q domain} "$work/updated.plist"
    '';
in
{
  /**
    Generate a command recursively merging a user preference dictionary

    Exported as `settings.live.mergeDict`. Preserve unrelated entries and import
    only the edited top-level key. Non-dictionary ancestors are replaced with
    dictionaries. Evaluation returns shell source without running it

    # Inputs

    `domain`
    : Plain user preference domain

    `key`
    : Dictionary preference key

    `entries`
    : Dictionary entries to merge

    # Type

    ```
    mergeDict :: String -> String -> AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.mergeDict` usage example

    ```nix
    s.live.mergeDict "com.example.app" "Preferences" { enabled = true; }
    ```

    :::
  */
  mergeDict =
    domain: key: entries:
    update "dictionary" domain key (path: dictionary path + merge path entries);
  /**
    Generate a command editing membership in a user preference string array

    Exported as `settings.live.setMembers`. True adds a missing string, false
    removes all copies. Preserve other members. Fail if an existing array
    contains non-string elements. Evaluation returns shell source without
    running it

    # Inputs

    `domain`
    : Plain user preference domain

    `key`
    : Array preference key

    `members`
    : Attribute set mapping stored strings to booleans

    # Type

    ```
    setMembers :: String -> String -> AttrSet -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.live.setMembers` usage example

    ```nix
    s.live.setMembers "com.example.app" "Applications" { "com.apple.Safari" = true; }
    ```

    :::
  */
  setMembers =
    domain: key: members:
    update "array" domain key (path: ''
      if [ "$(/usr/bin/plutil -type ${q path} "$work/updated.plist" 2>/dev/null)" != array ]; then
        /usr/bin/plutil -replace ${q path} -array "$work/updated.plist"
      fi
      # Validate stored members before editing the array
      count=$(/usr/bin/plutil -extract ${q path} raw -expect array -o - "$work/updated.plist")
      for ((at = 0; at < count; at++)); do
        /usr/bin/plutil -type ${q path}."$at" -expect string "$work/updated.plist" >/dev/null
      done
      ${lib.concatStrings (
        lib.mapAttrsToList (item: enabled: ''
          count=$(/usr/bin/plutil -extract ${q path} raw -expect array -o - "$work/updated.plist")
          found=false
          # Delete from the end so duplicate members cannot survive removal
          for ((at = count - 1; at >= 0; at--)); do
            # A sentinel preserves trailing newlines in stored string values
            stored=$(/usr/bin/plutil -extract ${q path}."$at" raw -expect string -n -o - "$work/updated.plist" && printf .)
            if [ "$stored" = ${q (item + ".")} ]; then
              found=true
              ${
                if enabled then "break" else ''/usr/bin/plutil -remove ${q path}."$at" "$work/updated.plist"''
              }
            fi
          done
          ${
            if enabled then
              ''
                if ! "$found"; then
                  /usr/bin/plutil -insert ${q path} -string ${q item} -append "$work/updated.plist"
                fi
              ''
            else
              ""
          }
        '') members
      )}
    '');
}

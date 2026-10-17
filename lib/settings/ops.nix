{ }:
# Plans stay plain data because the docs, optionIndex and the tools read them
{
  /**
    Describe a preference write

    The renderer infers the plist type unless the key overrides it

    Return plain data without executing a command

    # Inputs

    `key`
    : Storage key

    `value`
    : Plist value

    # Type

    ```
    write :: StorageKey -> Any -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.write` usage example

    ```nix
    s.ops.write (s.user "com.apple.dock" "autohide") true
    ```

    :::
  */
  write = key: value: {
    op = "write";
    inherit key value;
  };

  /**
    Describe deletion of a key, or of a whole domain when its name is null

    Return plain data without executing a command

    # Inputs

    `key`
    : Storage key

    # Type

    ```
    delete :: StorageKey -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.delete` usage example

    ```nix
    s.ops.delete (s.user "com.apple.dock" "autohide")
    ```

    :::
  */
  delete = key: {
    op = "delete";
    inherit key;
  };

  /**
    Describe an integer update that preserves bits outside a mask

    Return plain data without executing a command

    # Inputs

    `key`
    : Storage key

    `mask`
    : Mask of managed bits

    `bits`
    : Desired bits within the mask

    `absent`
    : Integer fallback when the key is absent

    # Type

    ```
    writeFlags :: StorageKey -> Int -> Int -> Int -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.writeFlags` usage example

    ```nix
    s.ops.writeFlags (s.global "ExampleFlags") 3 1 0
    ```

    :::
  */
  writeFlags = key: mask: bits: absent: {
    op = "writeFlags";
    inherit
      key
      mask
      bits
      absent
      ;
  };

  /**
    Describe a dictionary merge that preserves unrelated entries

    Nested dictionary updates require a plain user domain at rendering time

    Return plain data without executing a command

    # Inputs

    `key`
    : Storage key

    `entries`
    : Dictionary entries to merge

    # Type

    ```
    mergeDict :: StorageKey -> AttrSet -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.mergeDict` usage example

    ```nix
    s.ops.mergeDict (s.global "ExampleDict") { enabled = true; }
    ```

    :::
  */
  mergeDict = key: entries: {
    op = "mergeDict";
    inherit key entries;
  };

  /**
    Describe additions and removals in a string array

    True adds a string if missing, false removes every copy. Preserve other
    members. Rendering requires a plain user domain

    Return plain data without executing a command

    # Inputs

    `key`
    : Storage key

    `members`
    : Attribute set mapping stored strings to booleans

    # Type

    ```
    setMembers :: StorageKey -> AttrSet -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.setMembers` usage example

    ```nix
    s.ops.setMembers (s.global "ExampleList") { "com.apple.Safari" = true; }
    ```

    :::
  */
  setMembers = key: members: {
    op = "setMembers";
    inherit key members;
  };

  /**
    Describe replacement of a whole preference domain from a plist file

    The renderer deletes the destination domain before importing the file. The
    storage key's name does not limit the imported contents

    Return plain data without executing a command

    # Inputs

    `key`
    : Storage key identifying the domain

    `file`
    : Snapshot path

    # Type

    ```
    restore :: StorageKey -> String -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.restore` usage example

    ```nix
    s.ops.restore (s.domain "com.apple.dock") "/tmp/snapshot.plist"
    ```

    :::
  */
  restore = key: file: {
    op = "restore";
    inherit key file;
  };

  /**
    Describe trusted shell source to run in plan order

    Return plain data without executing a command

    # Inputs

    `command`
    : Shell source, inserted without escaping

    # Type

    ```
    run :: String -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.run` usage example

    ```nix
    s.ops.run "/usr/bin/true"
    ```

    :::
  */
  run = command: {
    op = "run";
    inherit command;
  };

  /**
    Describe shell source to run after notifications and restarts

    The renderer emits each distinct command once

    Return plain data without executing a command

    # Inputs

    `command`
    : Trusted shell source, inserted without escaping

    # Type

    ```
    afterwards :: String -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.afterwards` usage example

    ```nix
    s.ops.afterwards "/usr/bin/true"
    ```

    :::
  */
  afterwards = command: {
    op = "afterwards";
    inherit command;
  };

  /**
    Describe a notification to post after preference edits

    Return plain data without executing a command

    # Inputs

    `name`
    : Notification name passed literally to `notifyutil -p`

    # Type

    ```
    notify :: String -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.notify` usage example

    ```nix
    s.ops.notify "com.example.preferences.changed"
    ```

    :::
  */
  notify = name: {
    op = "notify";
    inherit name;
  };

  /**
    Describe an ordinary process restart after notification delivery

    Return plain data without executing a command

    # Inputs

    `process`
    : Process name passed literally to `killall`

    # Type

    ```
    restart :: String -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.restart` usage example

    ```nix
    s.ops.restart "Dock"
    ```

    :::
  */
  restart = process: {
    op = "restart";
    inherit process;
    discard = false;
  };

  /**
    Describe a SIGKILL process restart that prevents state from being saved

    Return plain data without executing a command

    # Inputs

    `process`
    : Process name passed literally to `killall`

    # Type

    ```
    restartDiscarding :: String -> Operation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.ops.restartDiscarding` usage example

    ```nix
    s.ops.restartDiscarding "Dock"
    ```

    :::
  */
  restartDiscarding = process: {
    op = "restart";
    inherit process;
    discard = true;
  };
}

{ lib, ops }:
let
  /**
    Append a request to restart a process after preference edits

    The renderer deduplicates requests by process name and uses `killall`

    # Inputs

    `process`
    : Process name

    # Type

    ```
    restarts :: String -> Behavior
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.restarts` usage example

    ```nix
    s.restarts "Dock"
    ```

    :::
  */
  restarts =
    process: _: plan:
    plan ++ [ (ops.restart process) ];

  /**
    Append a request to refresh keyboard shortcuts after all process restarts

    Run `activateSettings -u` only when the current user has a GUI launchd
    session. Users without a GUI session pick up shortcuts at login

    # Type

    ```
    activatesShortcuts :: Behavior
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.activatesShortcuts` usage example

    ```nix
    [ s.activatesShortcuts ]
    ```

    :::
  */
  activatesShortcuts =
    _: plan:
    plan
    ++ [
      (ops.afterwards ''if /bin/launchctl print "gui/$(/usr/bin/id -u)" >/dev/null 2>&1; then /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u; fi'')
    ];

  /**
    Append a SIGKILL restart request so a process cannot save stale state

    Use this for snapshot restoration when a normal quit would overwrite the
    restored preferences. Any discard request wins over ordinary restart
    requests for the same process

    # Inputs

    `process`
    : Process name

    # Type

    ```
    restartsDiscardingItsState :: String -> Behavior
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.restartsDiscardingItsState` usage example

    ```nix
    s.restartsDiscardingItsState "Dock"
    ```

    :::
  */
  restartsDiscardingItsState =
    process: _: plan:
    plan ++ [ (ops.restartDiscarding process) ];

  /**
    Append notification requests after preference edits

    The renderer posts each unique name with `notifyutil -p` before restarts

    # Inputs

    `names`
    : One notification name or a list of names

    # Type

    ```
    notifies :: (String | [String]) -> Behavior
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.notifies` usage example

    ```nix
    s.notifies [ "com.example.preferences.changed" ]
    ```

    :::
  */
  notifies =
    names: _: plan:
    plan ++ map ops.notify (lib.toList names);

  /**
    Replace a plan with commands produced from the configured value

    Preserve the existing plan for `"unset"`. This is the transformation used by
    a setting's `apply` argument, before explicit behaviors and host cleanup

    # Inputs

    `apply`
    : Function returning shell source or a list of shell source strings

    # Type

    ```
    appliesThrough :: (Any -> (String | [String])) -> Behavior
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.appliesThrough` usage example

    ```nix
    s.appliesThrough (enabled: "example-setter ${lib.boolToString enabled}")
    ```

    :::
  */
  appliesThrough =
    apply: context: plan:
    if context.value == "unset" then plan else map ops.run (lib.toList (apply context.value));

  /**
    Append deletions of stale host-specific copies of ordinary user keys

    Skip system keys, already host-specific keys, whole domains, and `~/` paths.
    This behavior runs by default after explicit setting behaviors

    # Type

    ```
    clearsByHostCopy :: Behavior
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.clearsByHostCopy` usage example

    ```nix
    [ s.clearsByHostCopy ]
    ```

    :::
  */
  clearsByHostCopy =
    context: plan:
    plan
    ++ lib.concatMap (
      key:
      lib.optional (
        key.scope == "user" && !key.byHost && key.name != null && !(lib.hasPrefix "~/" key.domain)
      ) (ops.delete (key // { byHost = true; }))
    ) (lib.attrValues context.keys);

  /**
    Supply the behaviors applied after each setting's explicit behaviors

    Currently contains only `clearsByHostCopy`

    # Type

    ```
    defaults :: [Behavior]
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.defaults` usage example

    ```nix
    s.defaults
    ```

    :::
  */
  defaults = [ clearsByHostCopy ];
in
{
  inherit
    restarts
    activatesShortcuts
    restartsDiscardingItsState
    notifies
    appliesThrough
    clearsByHostCopy
    defaults
    ;
}

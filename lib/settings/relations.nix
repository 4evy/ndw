{ lib }:
let
  result =
    kind: context: other: message: extra:
    {
      inherit kind message;
      id = "${context.path} -> ${other}";
    }
    // extra;

  withoutNulls =
    value:
    if lib.isAttrs value then
      lib.mapAttrs (_: withoutNulls) (lib.filterAttrs (_: v: v != null) value)
    else
      value;
  show = value: builtins.toJSON (withoutNulls value);

  unmanaged =
    context: other: reason:
    result "warning" context other
      "${context.path} = ${show context.value}: ${reason}, and ${other} isn't managed here."
      { };
in
{
  /**
    Warn when a setting has no effect unless another setting matches

    Warn when the other setting is unmanaged or its value fails the condition.
    Do not change the plan

    # Inputs

    `other`
    : Dotted catalog path of the required setting

    `condition`
    : Predicate on the other setting's non-null value

    `reason`
    : Explanation included in the diagnostic

    # Type

    ```
    onlyWhen :: String -> (Any -> Bool) -> String -> Relation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.onlyWhen` usage example

    ```nix
    s.onlyWhen "example.enabled" (enabled: enabled == true) "the feature is disabled"
    ```

    :::
  */
  onlyWhen =
    other: condition: reason: context:
    let
      otherValue = context.get other;
    in
    if otherValue == null then
      [ (unmanaged context other reason) ]
    else
      lib.optional (!(condition otherValue)) (
        result "warning" context other
          "${context.path} = ${show context.value} has no effect while ${other} = ${show otherValue}: ${reason}."
          { }
      );

  /**
    Reject a particular value unless another setting matches

    Only check when the source value equals `value`. Warn if the other setting
    is unmanaged, or return a failed assertion if its value fails the condition

    # Inputs

    `value`
    : Source value that activates the check

    `other`
    : Dotted catalog path

    `condition`
    : Predicate on the other setting's value

    `reason`
    : Explanation included in the diagnostic

    # Type

    ```
    allowedWhen :: Any -> String -> (Any -> Bool) -> String -> Relation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.allowedWhen` usage example

    ```nix
    s.allowedWhen true "example.enabled" (enabled: enabled == true) "requires the feature"
    ```

    :::
  */
  allowedWhen =
    value: other: condition: reason: context:
    let
      otherValue = context.get other;
    in
    if context.value != value then
      [ ]
    else if otherValue == null then
      [ (unmanaged context other reason) ]
    else
      lib.optional (!(condition otherValue)) (
        result "assertion" context other
          "${context.path} = ${show value} can't be combined with ${other} = ${show otherValue}: ${reason}."
          { }
      );

  /**
    Reject a value when another managed setting satisfies a predicate

    An unmanaged other setting produces no diagnostic

    # Inputs

    `other`
    : Dotted catalog path

    `condition`
    : Predicate identifying conflicting values of the other setting

    `reason`
    : Explanation included in the diagnostic

    # Type

    ```
    conflictsWith :: String -> (Any -> Bool) -> String -> Relation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.conflictsWith` usage example

    ```nix
    s.conflictsWith "example.exclusiveMode" (mode: mode == true) "the modes overlap"
    ```

    :::
  */
  conflictsWith =
    other: condition: reason: context:
    let
      otherValue = context.get other;
    in
    lib.optional (otherValue != null && condition otherValue) (
      result "assertion" context other
        "${context.path} = ${show context.value} can't be combined with ${other} = ${show otherValue}: ${reason}."
        { }
    );

  /**
    Turn value-specific problems into failed assertions

    # Inputs

    `problems`
    : Function returning a list of problem strings for the configured value

    # Type

    ```
    validates :: (Any -> [String]) -> Relation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.validates` usage example

    ```nix
    s.validates (value: lib.optional (value < 0) "must be nonnegative")
    ```

    :::
  */
  validates =
    problems: context:
    map (problem: {
      kind = "assertion";
      id = context.path;
      message = "${context.path}: ${problem}.";
    }) (problems context.value);

  /**
    Require another value and plan it when the other setting is unmanaged

    When unmanaged, warn and append `context.planFor other otherValue`. When
    managed with a different value, return a failed assertion. Silencing the
    warning does not remove the implied plan

    # Inputs

    `other`
    : Dotted catalog path

    `otherValue`
    : Required value for the other setting

    `reason`
    : Explanation included in the diagnostic

    # Type

    ```
    implies :: String -> Any -> String -> Relation
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.implies` usage example

    ```nix
    s.implies "example.enabled" true "setting the size also enables this feature"
    ```

    :::
  */
  implies =
    other: otherValue: reason: context:
    let
      current = context.get other;
    in
    if current == null then
      [
        (result "warning" context other
          "${context.path} = ${show context.value} also sets ${other} = ${show otherValue}: ${reason}. Set ${other} to make that explicit."
          { plan = context.planFor other otherValue; }
        )
      ]
    else
      lib.optional (current != otherValue) (
        result "assertion" context other
          "${context.path} = ${show context.value} needs ${other} = ${show otherValue}, not ${show current}: ${reason}."
          { }
      );
}

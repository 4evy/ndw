{ lib }:
{
  /**
    Map boolean value names to a checkbox's numeric selected state

    # Inputs

    `control`
    : Accessibility control identifier

    # Type

    ```
    checkbox :: String -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shows.checkbox` usage example

    ```nix
    s.shows.checkbox "Example"
    => { true = { Example = 1; }; false = { Example = 0; }; }
    ```

    :::
  */
  checkbox = control: {
    true = {
      ${control} = 1;
    };
    false = {
      ${control} = 0;
    };
  };

  /**
    Map choice labels to the displayed value of one control

    # Inputs

    `control`
    : Accessibility control identifier

    `choices`
    : Choice labels

    # Type

    ```
    choice :: String -> [String] -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shows.choice` usage example

    ```nix
    s.shows.choice "Position" [ "Left" "Right" ]
    ```

    :::
  */
  choice =
    control: choices:
    lib.genAttrs choices (choice: {
      ${control} = choice;
    });

  /**
    Map each choice to its selected radio button

    Prefix labels with `AXRadioButton:` and expect numeric state 1

    # Inputs

    `labels`
    : Choice labels

    # Type

    ```
    radio :: [String] -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shows.radio` usage example

    ```nix
    s.shows.radio [ "Light" "Dark" ]
    ```

    :::
  */
  radio =
    labels:
    lib.genAttrs labels (label: {
      "AXRadioButton:${label}" = 1;
    });

  /**
    Map codec value names to displayed values of one control

    # Inputs

    `control`
    : Accessibility control identifier

    `shown`
    : Attribute set from codec value names to displayed values

    # Type

    ```
    values :: String -> AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.shows.values` usage example

    ```nix
    s.shows.values "Slider" { "16" = 0.0; "128" = 1.0; }
    ```

    :::
  */
  values = control: shown: lib.mapAttrs (_: value: { ${control} = value; }) shown;
}

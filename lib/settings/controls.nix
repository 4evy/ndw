{
  lib,
  codecs,
  shows,
  core,
}:
let
  /**
    Declare an ordinary preference through an existing setting constructor

    Use the attribute form when the entry needs descriptions, relations, or
    other overrides. Shared defaults still come from the supplied constructor

    # Inputs

    `make`
    : Setting constructor, usually from a page or section

    `ui`
    : UI label or list of labels

    `storage`
    : Storage key or named key record

    `value`
    : Codec

    # Type

    ```
    preference :: Constructor -> (String | [String]) -> AttrSet -> Codec -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.preference` usage example

    ```nix
    s.preference s.setting "Tracking speed" (s.global "com.apple.trackpad.scaling")
      (s.numberBetween 0.0 3.0)
    ```

    :::
  */
  preference =
    make: ui: storage: value:
    make { inherit ui storage value; };

  /**
    Declare a checkbox through a toggle or specialized control constructor

    The constructor supplies its codec, behaviors, and verification defaults.
    Use a page's bound `checkbox` for ordinary boolean preferences

    # Inputs

    `make`
    : Constructor accepting `ui`, `storage`, and `control`

    `ui`
    : UI label or list of labels

    `storage`
    : Storage key or named key record

    `control`
    : Explicit accessibility control identifier

    # Type

    ```
    checkbox :: Constructor -> (String | [String]) -> AttrSet -> String -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.checkbox` usage example

    ```nix
    s.checkbox (s.toggle s.setting) "Show indicators"
      (s.user "com.apple.dock" "show-process-indicators") "show-indicators"
    ```

    :::
  */
  checkbox =
    make: ui: storage: control:
    make { inherit ui storage control; };

  # Keep verification overrides with the setting that needs them
  verified =
    make:
    {
      click ? false,
      ...
    }@args:
    control: expect:
    make (
      removeAttrs args [ "click" ]
      // {
        ui = lib.toList args.ui;
        verify = lib.mapNullable (
          spec:
          {
            inherit expect;
          }
          // lib.optionalAttrs click {
            operate = [
              "click"
              control
            ];
          }
          // spec
        ) (args.verify or { });
      }
    );
  /**
    Declare a boolean control with UI verification expectations

    Default `control` to the last UI label prefixed with `AXCheckBox:` and
    `value` to `bool`. Other arguments pass through to the constructor. Explicit
    verification attributes override generated expectations. Set `verify = null`
    to disable verification or `click = true` to generate a click operation

    # Inputs

    `make`
    : Setting constructor, such as `setting` or a section constructor

    `args`
    : Setting arguments with optional `control`, `value`, and `click` overrides

    # Type

    ```
    toggle :: Constructor -> AttrSet -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.toggle` usage example

    ```nix
    s.toggle s.setting {
      ui = "Tap to click";
      storage = s.user "com.apple.AppleMultitouchTrackpad" "Clicking";
    }
    ```

    :::
  */
  toggle =
    make:
    {
      ui,
      control ? "AXCheckBox:${lib.last (lib.toList ui)}",
      value ? codecs.bool,
      ...
    }@args:
    verified make (removeAttrs args [ "control" ] // { inherit value; }) control (
      shows.checkbox control
    );

  /**
    Declare a choice control with representative UI verification cases

    Default `control` to the last UI label prefixed with `AXPopUpButton:` and
    `choices` to the codec's choices. Override `choices` to limit verification
    cases. Other arguments and verification overrides work as with `toggle`

    # Inputs

    `make`
    : Setting constructor

    `args`
    : Setting arguments, including a codec and optional `control` and `choices`

    # Type

    ```
    select :: Constructor -> AttrSet -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.select` usage example

    ```nix
    s.select s.setting {
      ui = "Position on screen";
      storage = s.user "com.apple.dock" "orientation";
      value = s.enum { Left = "left"; Bottom = "bottom"; Right = "right"; };
      choices = [ "Left" "Bottom" ];
    }
    ```

    :::
  */
  select =
    make:
    {
      ui,
      control ? "AXPopUpButton:${lib.last (lib.toList ui)}",
      choices ? args.value.choices,
      ...
    }@args:
    verified make (removeAttrs args [
      "control"
      "choices"
    ]) control (shows.choice control choices);

  /**
    Declare a control whose stored values differ from displayed values

    Build expectations with `shows.values`. Other arguments, including explicit
    verification overrides, pass through as with `toggle`

    # Inputs

    `make`
    : Setting constructor

    `args`
    : Setting arguments plus a required `control` identifier and `expect`
      mapping from codec value names to displayed values

    # Type

    ```
    control :: Constructor -> AttrSet -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.control` usage example

    ```nix
    s.control s.setting {
      ui = "Size";
      storage = s.user "com.apple.dock" "tilesize";
      value = s.numberBetween 16 128;
      control = "Dock Size";
      expect = { "16" = 0.0; "128" = 1.0; };
    }
    ```

    :::
  */
  control =
    make:
    { control, expect, ... }@args:
    verified make (removeAttrs args [
      "control"
      "expect"
    ]) control (shows.values control expect);

  /**
    Declare a radio group with one named control per choice

    Default `choices` to the codec's choices. Each case expects its
    `AXRadioButton:<label>` to be selected. Supply an explicit `verify.operate`
    if interaction is needed, as this constructor has no single click target

    # Inputs

    `make`
    : Setting constructor

    `args`
    : Setting arguments with optional `choices` limiting verification cases

    # Type

    ```
    radio :: Constructor -> AttrSet -> Setting
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.radio` usage example

    ```nix
    s.radio s.setting {
      ui = "Appearance";
      storage = s.global "ExampleAppearance";
      value = s.enum { Light = 0; Dark = 1; };
    }
    ```

    :::
  */
  radio =
    make:
    {
      choices ? args.value.choices,
      ...
    }@args:
    verified make (removeAttrs args [ "choices" ]) null (shows.radio choices);

  /**
    Bundle setting constructors with shared UI and verification defaults

    Return bound `setting`, `preference`, `checkbox`, `toggle`, `select`,
    `control`, and `radio` constructors. `section defaults` nests another UI
    prefix with `sectionWith` semantics. `navigate ui open` also replaces the
    verification navigation path, which starts at the pane root

    Plain settings still require explicit `verify` specifications. Control
    constructors generate their own expectations

    # Inputs

    `defaults`
    : Shared arguments, usually a UI prefix and verification context

    # Type

    ```
    page :: AttrSet -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.page` usage example

    ```nix
    let
      page = s.page {
        ui = [ "System Settings" "Sound" ];
        verify.pane = "com.apple.settings.sounds";
      };
      nested = page.navigate "Sound Effects" [ "Sound Effects" ];
    in
    nested.toggle { ui = "Example switch"; storage = s.global "ExampleSwitch"; }
    ```

    :::
  */
  page = defaults: controlsFor (core.section defaults);

  /**
    Create a page rooted in System Settings

    Prefix the UI path with `"System Settings"` and set `verify.pane`. The
    returned constructors and nesting methods are the same as `page`

    # Inputs

    `ui`
    : Label or list of labels below System Settings

    `pane`
    : System Settings pane identifier

    # Type

    ```
    systemPage :: (String | [String]) -> String -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.systemPage` usage example

    ```nix
    s.systemPage "Sound" "com.apple.settings.sounds"
    ```

    :::
  */
  systemPage =
    ui: pane:
    page {
      ui = [ "System Settings" ] ++ lib.toList ui;
      verify = { inherit pane; };
    };

  /**
    Bind control constructors and nesting methods to a setting constructor

    Use this when a specialized constructor already supplies shared behavior.
    Bare settings disable verification unless the entry explicitly supplies it.
    See `page` for the returned constructor and nesting methods

    # Inputs

    `make`
    : Setting constructor to bind

    # Type

    ```
    controlsFor :: Constructor -> AttrSet
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.controlsFor` usage example

    ```nix
    s.controlsFor (s.section { ui = "Dock"; })
    ```

    :::
  */
  controlsFor =
    make:
    let
      setting = args: make (args // { verify = args.verify or null; });
    in
    {
      inherit setting;
      preference = preference setting;
      checkbox = checkbox (toggle make);
      toggle = toggle make;
      select = select make;
      control = control make;
      radio = radio make;
      section = defaults: controlsFor (core.sectionWith make defaults);
      # UI labels extend the section, while open is a path from the pane root
      navigate =
        ui: open:
        controlsFor (
          core.sectionWith make {
            inherit ui;
            verify.open = lib.toList open;
          }
        );
    };
in
{
  inherit
    toggle
    select
    control
    radio
    page
    systemPage
    controlsFor
    preference
    checkbox
    ;
}

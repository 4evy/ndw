{ lib, ... }:
let
  inherit (lib.darwin.options) mkNullableOption;
  # macOS stores the selected value as its index in this list
  choices = [
    "Do Nothing"
    "Change Input Source"
    "Show Emoji & Symbols"
    "Start Dictation"
  ];
in

{
  options.system.defaults.hitoolbox = {

    AppleFnUsageType =
      mkNullableOption (lib.types.enum choices) ''
        Chooses what happens when you press the Fn key on the keyboard. A restart is required for
        this setting to take effect.

        The default is unset ("Show Emoji & Symbols").
      ''
      // {
        apply = lib.trivial.mapNullable (key: lib.lists.findFirstIndex (value: value == key) null choices);
      };

  };
}

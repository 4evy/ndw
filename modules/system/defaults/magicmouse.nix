{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.magicmouse = {
    MouseButtonMode =
      mkNullableOption
        (types.enum [
          "OneButton"
          "TwoButton"
        ])
        ''
          "OneButton": any tap is a left click.  "TwoButton": allow left-
          and right-clicking.
        '';
  };
}

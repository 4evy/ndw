{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.spaces = {
    spans-displays = mkNullableOption types.bool ''
      Apple menu > System Preferences > Mission Control

      Displays have separate Spaces (note a logout is required before
      this setting will take effect).

      false = each physical display has a separate space (Mac default)
      true = one space spans across all physical displays
    '';
  };
}

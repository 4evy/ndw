{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.LaunchServices = {
    LSQuarantine = mkNullableOption types.bool ''
      Whether to enable quarantine for downloaded applications.  The default is true.
    '';
  };
}

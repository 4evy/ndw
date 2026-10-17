{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.SoftwareUpdate = {
    AutomaticallyInstallMacOSUpdates = mkNullableOption types.bool ''
      Automatically install Mac OS software updates. Defaults to false.
    '';
  };
}

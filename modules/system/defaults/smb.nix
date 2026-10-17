{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.smb = {
    NetBIOSName = mkNullableOption types.str "Hostname to use for NetBIOS.";

    ServerDescription = mkNullableOption types.str "Hostname to use for sharing services.";
  };
}

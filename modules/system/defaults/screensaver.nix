{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.screensaver = {
    askForPassword = mkNullableOption types.bool ''
      If true, the user is prompted for a password when the screen saver is unlocked or stopped. The default is false.
    '';

    askForPasswordDelay = mkNullableOption types.int ''
      The number of seconds to delay before the password will be required to unlock or stop the screen saver (the grace period).
    '';
  };
}

{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.".GlobalPreferences" = {
    "com.apple.sound.beep.sound" = mkNullableOption (types.path) ''
      Sets the system-wide alert sound. Found under "Sound Effects" in the
      "Sound" section of "System Preferences". Look in
      "/System/Library/Sounds" for possible candidates.
    '';

    "com.apple.mouse.scaling" =
      mkNullableOption types.float ''
        Sets the mouse tracking speed. Found in the "Mouse" section of
        "System Preferences". Set to -1.0 to disable mouse acceleration.
      ''
      // {
        example = -1.0;
      };
  };
}

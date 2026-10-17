{ lib, ... }:
let
  inherit (lib.darwin.options) mkNullableOption;
in
{
  # KeyboardSettings uses NSUserDefaults with the com.apple.TextInputMenu
  # suite
  options.system.defaults.TextInputMenu.visible = mkNullableOption lib.types.bool ''
    Show the input menu in the menu bar to switch input sources.
    Logging out may be needed to apply the preference
  '';
}

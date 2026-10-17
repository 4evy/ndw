{ lib, ... }:
let
  inherit (lib.darwin.options) mkNullableOption;
  menuItem =
    location: description:
    mkNullableOption (lib.types.either lib.types.bool lib.types.ints.unsigned) ''
      Control Center menu bar mode for ${location}

      ${description} Null leaves the current preference unchanged

      Accepts the native integer mode, including 2 for show when active,
      8 for hidden, and 18 for always shown where supported by macOS. The
      available modes depend on the item and macOS version

      Boolean true writes 18 and false writes 8. Use an integer for other modes
    ''
    // {
      apply = lib.trivial.mapNullable (
        value: if builtins.isBool value then (if value then 18 else 8) else value
      );
    };
in

{
  options.system.defaults.controlcenter = {

    BatteryShowPercentage = mkNullableOption lib.types.bool ''
      Apple menu > System Preferences > Control Center > Battery

      Show a battery percentage in menu bar. Default is null.
    '';

    # ControlCenter.framework's BatteryPreferences.ShowEnergyModeOption
    # maps whenActive to 0 and always to 1
    BatteryShowEnergyMode =
      mkNullableOption
        (lib.types.enum [
          0
          1
        ])
        ''
          When to show the battery's energy mode in the menu bar. Zero shows it
          when an energy mode is active and one always shows it. Available on
          macOS versions that support the energy mode indicator

          Null leaves the current host's preference unchanged
        '';

    Sound = menuItem "Sound" "Visibility of the sound control in the menu bar.";

    Bluetooth = menuItem "Bluetooth" "Visibility of the Bluetooth control in the menu bar.";

    AirDrop = menuItem "AirDrop" "Visibility of the AirDrop control in the menu bar.";

    Display = menuItem "Display" "Visibility of the screen brightness control in the menu bar.";

    FocusModes = menuItem "Focus" "Visibility of the Focus control in the menu bar.";

    NowPlaying = menuItem "Now Playing" "Visibility of the Now Playing control in the menu bar.";

    WiFi = menuItem "Wi-Fi" "Visibility of the Wi-Fi control in the menu bar.";

    StageManager = menuItem "Stage Manager" "Visibility of the Stage Manager control in the menu bar.";

    ScreenMirroring = menuItem "Screen Mirroring" "Visibility of the Screen Mirroring control in the menu bar.";

  };
}

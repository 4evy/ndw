{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.menuExtraClock = {
    FlashDateSeparators = mkNullableOption types.bool ''
      When enabled, the clock indicator (which by default is the colon) will flash on and off each second. Default is null.
    '';

    IsAnalog = mkNullableOption types.bool ''
      Show an analog clock instead of a digital one. Default is null.
    '';

    Show24Hour = mkNullableOption types.bool ''
      Show a 24-hour clock, instead of a 12-hour clock. Default is null.
    '';

    ShowAMPM = mkNullableOption types.bool ''
      Show the AM/PM label. Useful if Show24Hour is false. Default is null.
    '';

    ShowDayOfMonth = mkNullableOption types.bool ''
      Show the day of the month. Default is null.
    '';

    ShowDayOfWeek = mkNullableOption types.bool ''
      Show the day of the week. Default is null.
    '';

    ShowDate =
      mkNullableOption
        (types.enum [
          0
          1
          2
        ])
        ''
          Show the full date. Default is null.

          0 = When space allows
          1 = Always
          2 = Never
        '';

    ShowSeconds = mkNullableOption types.bool ''
      Show the clock with second precision, instead of minutes. Default is null.
    '';
  };
}

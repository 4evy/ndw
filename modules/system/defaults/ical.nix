{ lib, ... }:
let
  inherit (lib.darwin.options) mkNullableOption;
  # macOS stores the selected value as its index in this list
  choices = [
    "System Setting"
    "Sunday"
    "Monday"
    "Tuesday"
    "Wednesday"
    "Thursday"
    "Friday"
    "Saturday"
  ];
in

{
  options.system.defaults.iCal = {
    "first day of week" =
      mkNullableOption (lib.types.enum choices) ''
        Set the day to start week on in the Calendar. The default is "System Setting".

        System Setting means inherit the value from Language & Region.
      ''
      // {
        apply = lib.trivial.mapNullable (key: lib.lists.findFirstIndex (value: value == key) null choices);
      };

    CalendarSidebarShown = mkNullableOption lib.types.bool ''
      Show calendar list. The default is false.

      This requires restarting `Calendar.app` to show.
    '';

    "TimeZone support enabled" = mkNullableOption lib.types.bool ''
      Turn on time zone support. The default is false.
    '';
  };
}

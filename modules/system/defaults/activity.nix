{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.ActivityMonitor = {
    ShowCategory =
      mkNullableOption
        (types.enum [
          100
          101
          102
          103
          104
          105
          106
          107
        ])
        ''
          Change which processes to show.
          * 100: All Processes
          * 101: All Processes, Hierarchally
          * 102: My Processes
          * 103: System Processes
          * 104: Other User Processes
          * 105: Active Processes
          * 106: Inactive Processes
          * 107: Windowed Processes
          Default is 100.
        '';

    IconType = mkNullableOption types.int ''
      Change the icon in the dock when running.
      * 0: Application Icon
      * 2: Network Usage
      * 3: Disk Activity
      * 5: CPU Usage
      * 6: CPU History
      Default is null.
    '';

    SortColumn = mkNullableOption types.str ''
      Which column to sort the main activity page (such as "CPUUsage"). Default is null.
    '';

    SortDirection = mkNullableOption types.int ''
      The sort direction of the sort column (0 is decending). Default is null.
    '';

    OpenMainWindow = mkNullableOption types.bool ''
      Open the main window when opening Activity Monitor. Default is true.
    '';
  };
}

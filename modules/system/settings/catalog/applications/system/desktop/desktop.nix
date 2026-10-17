{ lib, settingsLib }:
let
  imports = { inherit lib settingsLib; };
in
{
  dock = import ./dock.nix imports;
  desktopAndStageManager = import ./stage.nix imports;
  widgets = import ./widgets.nix imports;
  windows = import ./windows.nix imports;
  missionControl = import ./mission.nix imports;
  hotCorners = import ./corners.nix imports;
}

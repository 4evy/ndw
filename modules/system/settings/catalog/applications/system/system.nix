{ lib, settingsLib }:
let
  load = file: import file { inherit lib settingsLib; };
in
{
  general = load ./general/general.nix;
  accessibility = load ./accessibility.nix;
  appearance = load ./appearance.nix;
  appleIntelligenceAndSiri = load ./intelligence.nix;
  desktopAndDock = load ./desktop/desktop.nix;
  displays = load ./displays.nix;
  battery = load ./battery.nix;
  menuBar = load ./menu.nix;
  spotlight = load ./spotlight.nix;
  wallpaper = load ./wallpaper/wallpaper.nix;
  notifications = load ./notifications.nix;
  sound = load ./sound.nix;
  focus = load ./focus.nix;
  lockScreen = load ./lock.nix;
  keyboard = load ./keyboard.nix;
  trackpad = load ./trackpad.nix;
  printersAndScanners = load ./printers.nix;
  privacyAndSecurity = load ./privacy.nix;
  network = load ./network.nix;
  wiFi = load ./wifi.nix;
}

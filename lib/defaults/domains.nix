{ lib }:
let
  merge =
    groups:
    lib.zipAttrsWith (
      _: values:
      lib.foldl' (acc: group: acc // lib.filterAttrs (_: value: value != null) group) { } values
    ) groups;
in
/**
  Group evaluated `system.defaults` values by preference scope and domain

  Return `system`, `user`, and `userByHost` domain maps for `defaults.commands`.
  Omit null-valued keys. Merge groups in order, so later non-null values replace
  earlier values for the same domain and key

  Custom system and user preferences override the corresponding built-in groups.
  For host-specific preferences, the built-in control-center and user-activity
  groups override custom keys. Trackpad and mouse groups are copied to both
  domain identifiers used by macOS

  # Inputs

  `cfg`
  : Evaluated `config.system.defaults`, including all built-in and custom
    preference groups. An arbitrary partial attribute set is not sufficient

  # Type

  ```
  domains :: AttrSet -> { system :: AttrSet; user :: AttrSet; userByHost :: AttrSet; }
  ```

  # Examples
  :::{.example}
  ## `lib.darwin.defaults.domains` usage example

  ```nix
  { config, lib, ... }:
  let
    domains = lib.darwin.defaults.domains config.system.defaults;
  in
  {
    system.activation.steps.example.text = lib.darwin.shell.commandLines (
      lib.darwin.defaults.commands {} domains.system
    );
  }
  ```

  :::
*/
cfg: {
  system = merge [
    {
      "/Library/Preferences/com.apple.loginwindow" = cfg.loginwindow;
      "/Library/Preferences/SystemConfiguration/com.apple.smb.server" = cfg.smb;
      "/Library/Preferences/com.apple.SoftwareUpdate" = cfg.SoftwareUpdate;
    }
    cfg.CustomSystemPreferences
  ];
  user = merge [
    {
      ".GlobalPreferences" = cfg.".GlobalPreferences";
      "com.apple.LaunchServices" = cfg.LaunchServices;
      "-g" = cfg.NSGlobalDomain;
      "com.apple.menuextra.clock" = cfg.menuExtraClock;
      "com.apple.dock" = cfg.dock;
      "com.apple.finder" = cfg.finder;
      "com.apple.HIToolbox" = cfg.hitoolbox;
      "com.apple.TextInputMenu" = cfg.TextInputMenu;
      "com.apple.iCal" = cfg.iCal;
      "com.apple.AppleMultitouchMouse" = cfg.magicmouse;
      "com.apple.driver.AppleMultitouchMouse.mouse" = cfg.magicmouse;
      "com.apple.screencapture" = cfg.screencapture;
      "com.apple.screensaver" = cfg.screensaver;
      "com.apple.spaces" = cfg.spaces;
      "com.apple.AppleMultitouchTrackpad" = cfg.trackpad;
      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = cfg.trackpad;
      "com.apple.universalaccess" = cfg.universalaccess;
      "com.apple.ActivityMonitor" = cfg.ActivityMonitor;
      "com.apple.WindowManager" = cfg.WindowManager;
    }
    cfg.CustomUserPreferences
  ];

  userByHost = merge [
    cfg.CustomUserPreferencesByHost
    {
      "com.apple.controlcenter" = cfg.controlcenter;
      "com.apple.coreservices.useractivityd" = cfg.useractivityd;
    }
  ];
}

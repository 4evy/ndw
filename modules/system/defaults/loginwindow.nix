{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.darwin.options) mkNullableOption;
in

{
  options.system.defaults.loginwindow = {
    SHOWFULLNAME = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Displays login window as a name and password field instead of a list of users.
      Default is false.
    '';

    HideUserAvatarAndName = mkNullableOption types.bool ''
      Apple menu > System Settings > Lock Screen

      Hides the username and photo on the login screen, showing only a password prompt. Default is false.
    '';

    autoLoginUser = mkNullableOption types.str ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Select the account used for automatic login on boot. This only writes
      the account name and does not configure the account's login credentials
    '';

    GuestEnabled = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Allow users to log in using the Guest account. Null leaves the current
      preference unchanged
    '';

    LoginwindowText = mkNullableOption types.str ''
      Text to be shown on the login window. Null leaves the current
      preference unchanged
    '';

    ShutDownDisabled = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Hides the Shut Down button on the login screen. Default is false.
    '';

    SleepDisabled = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Hides the Sleep button on the login screen. Default is false.
    '';

    RestartDisabled = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Hides the Restart button on the login screen. Default is false.
    '';

    ShutDownDisabledWhileLoggedIn = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Disables the "Shutdown" option when users are logged in. Default is false.
    '';

    PowerOffDisabledWhileLoggedIn = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      If set to true, the Power Off menu item will be disabled when the user is logged in. Default is false.
    '';

    RestartDisabledWhileLoggedIn = mkNullableOption types.bool ''
      Apple menu > System Preferences > Users and Groups > Login Options

      Disables the “Restart” option when users are logged in. Default is false.
    '';

    DisableConsoleAccess = mkNullableOption types.bool ''
      Disables the ability for a user to access the console by typing “>console”
      for a username at the login window. Default is false.
    '';
  };
}

{ lib, settingsLib, ... }:
let
  page = settingsLib.systemPage "Privacy & Security" "com.apple.settings.privacyAndSecurity";
  inherit (page) setting toggle preference;

  inherit (settingsLib)
    numberBetween
    user
    system
    file
    mkKey
    bool
    ops
    ;

  diagnostics =
    name:
    mkKey {
      domain = "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory";
      inherit name;
      scope = "system";
    };

  # A shared rule lets any user unlock the system-wide panes. otherwise only
  # an administrator can
  systemPreferencesRight =
    shared:
    lib.concatStringsSep "; " [
      "rule=$(/usr/bin/mktemp)"
      "/usr/bin/security authorizationdb read system.preferences > \"$rule\" 2>/dev/null"
      "/usr/bin/plutil -replace shared -bool ${lib.boolToString shared} \"$rule\""
      "/usr/bin/security authorizationdb write system.preferences < \"$rule\" >/dev/null 2>&1"
      "rm -f \"$rule\""
    ];
in
{
  analyticsAndImprovements = {
    shareMacAnalytics = preference [
      "Analytics & Improvements"
      "Share Mac Analytics"
    ] (diagnostics "AutoSubmit") bool;

    shareWithAppDevelopers = preference [
      "Analytics & Improvements"
      "Share with app developers"
    ] (diagnostics "ThirdPartyDataSubmit") bool;
  };

  appleAdvertising.personalizedAds = preference [
    "Apple Advertising"
    "Personalized Ads"
  ] (user "com.apple.AdLib" "allowApplePersonalizedAdvertising") bool;

  advanced = {
    requireAnAdministratorPasswordToAccessSystemWideSettings = toggle {
      ui = [
        "Advanced…"
        "Require an administrator password to access system-wide settings"
      ];
      storage = file "security authorizationdb system.preferences";
      apply = required: systemPreferencesRight (!required);
      control = "AXCheckBox:PreferenceLock_Toggle";
      verify.open = [ "AXButton:Advanced…" ];
    };

    logOutAutomaticallyAfterInactivity = setting {
      ui = [
        "Advanced…"
        "Log out automatically after inactivity"
      ];
      description = "Minutes of inactivity before logging out; 0 doesn't log out.";
      storage = system ".GlobalPreferences" "com.apple.autologout.AutoLogOutDelay";
      value = numberBetween 0 960 // {
        encode = keys: minutes: [ (ops.write keys.value (minutes * 60)) ];
        decode =
          keys: get:
          let
            seconds = get keys.value;
          in
          if seconds == null then null else seconds / 60;
      };
      verify = {
        open = [ "AXButton:Advanced…" ];
        expect = {
          "0" = {
            "AXCheckBox:AutoLogout_Toggle" = 0;
          };
          "60" = {
            "AXCheckBox:AutoLogout_Toggle" = 1;
            "AXIncrementor:Log out after" = 60;
          };
        };
      };
    };
  };
}

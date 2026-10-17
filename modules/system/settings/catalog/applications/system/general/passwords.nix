{ settingsLib, ... }:
let
  page = (settingsLib.systemPage "General" "com.apple.settings.general").navigate "AutoFill & Passwords" open;
  inherit (page) checkbox preference;

  inherit (settingsLib)
    eachKey
    bool
    user
    ;

  open = [ "com.apple.systempreferences.general.passwords" ];
in
{
  autoFillPasswordsAndPasskeys =
    checkbox "AutoFill Passwords and Passkeys" (user "com.apple.Safari" "AutoFillPasswords")
      "AXCheckBox:AutoFillToggle + AutoFill Passwords and Passkeys";

  autoFillFromPasswords = checkbox [
    "AutoFill from"
    "Passwords"
  ] (user "com.apple.Safari" "AutoFillFromiCloudKeychain") "AXCheckBox:AutoFillFromPasswordsToggle";

  # System Settings shows this switch from elsewhere, so it can't be verified
  deleteVerificationCodesAfterUse =
    preference
      [
        "Verification Codes"
        "Delete After Use"
      ]
      {
        messages = user "com.apple.MobileSMS" "DeleteVerificationCodes";
        mail = user "com.apple.onetimepasscodes" "DeleteVerificationCodes";
      }
      (eachKey bool);
}

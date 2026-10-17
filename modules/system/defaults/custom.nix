{ lib, pkgs, ... }:

let
  inherit (lib) types;
  inherit (lib.darwin.options) mkDefaultOption;
  valueType = (pkgs.formats.plist { }).type // {
    description = "plist value";
  };
  defaultsType = types.attrsOf (types.attrsOf valueType);
  example = {
    "NSGlobalDomain" = {
      "TISRomanSwitchState" = 1;
    };
    "com.apple.Safari" = {
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
    };
  };
in
{
  options.system.defaults = {
    CustomUserPreferences =
      mkDefaultOption defaultsType { } ''
        Sets custom user preferences
      ''
      // {
        inherit example;
      };

    CustomSystemPreferences =
      mkDefaultOption defaultsType { } ''
        Sets custom system preferences
      ''
      // {
        inherit example;
      };

    CustomUserPreferencesByHost =
      mkDefaultOption defaultsType { } ''
        Sets custom user preferences for the current host using
        `defaults -currentHost` as `system.primary.user`. Top-level keys set
        to null are ignored. Removing a key from the configuration leaves
        its current preference unchanged

        Values may be scalars, arrays, or dictionaries. Some applications
        require a restart or re-login before reading the updated preferences
      ''
      // {
        example = {
          "com.apple.Spotlight".MenuItemHidden = true;
          "NSGlobalDomain"."com.apple.keyboard.modifiermapping.1118-1957-0" = [
            {
              HIDKeyboardModifierMappingSrc = 30064771298;
              HIDKeyboardModifierMappingDst = 30064771299;
            }
          ];
        };
      };
  };
}

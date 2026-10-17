{ lib, ... }:
let
  inherit (lib.darwin.options) mkNullableOption;
in
{
  # AirDropHandoffExtension writes both keys for currentUser/currentHost
  options.system.defaults.useractivityd = {
    ActivityAdvertisingAllowed = mkNullableOption lib.types.bool ''
      Allow this Mac to advertise activities for Handoff to other devices.
      Enable ActivityReceivingAllowed as well to match the Handoff switch
      in System Settings. Logging out may be needed to apply the preference
    '';

    ActivityReceivingAllowed = mkNullableOption lib.types.bool ''
      Allow this Mac to receive activities through Handoff from other devices.
      Enable ActivityAdvertisingAllowed as well to match the Handoff switch
      in System Settings. Logging out may be needed to apply the preference
    '';
  };
}

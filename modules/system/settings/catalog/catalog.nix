{ lib, settingsLib }:
{
  applications = import ./applications/applications.nix { inherit lib settingsLib; };
}

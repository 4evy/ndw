{ lib, settingsLib, ... }:
let
  section = file: import file { inherit lib settingsLib; };
in
{
  airDropAndContinuity = section ./airdrop.nix;
  autoFillAndPasswords = section ./passwords.nix;
  dateAndTime = section ./date.nix;
  languageAndRegion = section ./language.nix;
  sharing = section ./sharing.nix;
  softwareUpdate = section ./update.nix;
}

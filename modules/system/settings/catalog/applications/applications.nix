{ lib, settingsLib }:
let
  load = file: import file { inherit lib settingsLib; };
in
{
  systemSettings = load ./system/system.nix;
  voiceMemos = load ./memos.nix;
  journal = load ./journal.nix;
  finder = load ./finder.nix;
}

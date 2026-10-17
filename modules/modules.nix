{
  _class = "darwin";

  imports = [
    ./aliases/aliases.nix
    ./nixpkgs/nixpkgs.nix
    ./determinate/determinate.nix
    ./system/system.nix
    ./system/applications.nix
    ./system/activation.nix
    ./system/boot.nix
    ./environment/environment.nix
    ./files/files.nix
    ./users/users.nix
    ./networking/networking.nix
    ./system/defaults/defaults.nix
    ./system/settings/settings.nix
    ./bash/bash.nix
    ./zsh/zsh.nix
    ./launchd/launchd.nix
    ./homebrew/homebrew.nix
  ];
}

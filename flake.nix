{
  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib.extend (
        self: _: {
          darwin =
            import ./lib/lib.nix {
              lib = self;
              inherit settingsScripts;
            }
            // {
              system = import ./lib/system.nix {
                lib = self;
                determinate = inputs.determinate;
                nixpkgs = inputs.nixpkgs;
                revision = inputs.self.rev or inputs.self.dirtyRev or null;
              };
            };
        }
      );
      pkgs = import inputs.nixpkgs { system = "aarch64-darwin"; };
      settingsScripts = pkgs.callPackage ./lib/settings/scripts.nix { };
      darwin = pkgs.callPackage ./rebuild/rebuild.nix { inherit lib; };
      settingsTools = pkgs.callPackage ./lib/settings/tools.nix {
        inherit lib;
        settingsRoot = inputs.self;
      };
    in
    {
      lib.darwin = lib.darwin;
      packages.aarch64-darwin = {
        inherit darwin;
        default = darwin;
        darwin-settings = settingsTools;
        darwin-settings-scripts = settingsScripts;
      };
      checks.aarch64-darwin.settings-scripts = settingsScripts;
      apps.aarch64-darwin =
        lib.genAttrs [ "settings-current" "settings-capture" "settings-apply" ]
          (name: {
            type = "app";
            program = "${settingsTools}/bin/darwin-${name}";
          });
      formatter.aarch64-darwin = pkgs.nixfmt;
    };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.determinate.url = "github:DeterminateSystems/determinate/v3.23.2";

  description = "Darwin activation, shells, and launchd";
}

{ lib }:
/**
  Evaluate an ndw configuration using nix-darwin's flake arguments

  ndw retains its own modules and supports only aarch64-darwin. This entry
  point keeps the legacy shell enable and startup defaults.

  # Inputs

  `modules`: Modules to evaluate in addition to ndw's built-in modules.

  `pkgs`: Optional preconfigured package set, defaulting to `null`.

  `system`: Optional legacy platform string, defaulting to `aarch64-darwin`.

  `specialArgs`: Extra arguments available even in imports, defaulting to `{}`.

  `inputs`: Legacy module argument, omitted when `null` (the default).

  # Type

  ```
  darwinSystem :: { modules :: [Module]; pkgs? :: Pkgs | Null;
                    system? :: String; specialArgs? :: AttrSet;
                    inputs? :: AttrSet | Null; } -> AttrSet
  ```

  # Examples

  :::{.example}
  ## `lib.darwinSystem` usage example

  ```nix
  (inputs.nix-darwin.lib.darwinSystem {
    modules = [ { system.primaryUser = "evy"; } ];
  }).config.system.primary.user
  => "evy"
  ```

  :::
*/
{
  modules,
  pkgs ? null,
  system ? "aarch64-darwin",
  specialArgs ? { },
  inputs ? null,
}:
assert lib.asserts.assertMsg (system == "aarch64-darwin") "ndw supports only aarch64-darwin";
lib.darwin.system {
  inherit pkgs;
  modules =
    modules
    ++ [
      {
        programs.bash.enable = lib.modules.mkDefault true;
        programs.bash.completion.enable = lib.modules.mkDefault false;
        programs.zsh.enable = lib.modules.mkDefault true;
        programs.zsh.enableBashCompletion = lib.modules.mkDefault true;
        programs.zsh.promptInit = lib.modules.mkDefault "autoload -U promptinit && promptinit && prompt suse && setopt prompt_sp";
      }
    ]
    ++ lib.lists.optional (inputs != null) { _module.args = { inherit inputs; }; };
  special.args = specialArgs;
}

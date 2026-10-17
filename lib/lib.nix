/**
  Darwin helpers exported by the flake as `lib.darwin`

  Inside Darwin modules, use the supplied `lib.darwin`. Outside modules, use
  `inputs.darwin.lib.darwin`. This attribute set extends Nixpkgs through a
  namespace, so helpers such as `options.mkDefaultOption` are not aliases in the
  top-level Nixpkgs library

  - `options` and `types` declare module options
  - `paths` checks relative file names without accessing the filesystem
  - `shell` and `zsh` generate shell source
  - `defaults` converts preference domains to command argument lists
  - `settings` declares typed settings, plans changes, and generates scripts

  The flake also adds `system`, which evaluates a Darwin configuration

  Reference documentation lives above the corresponding definitions, following
  Nixpkgs' documentation-comment convention with inputs, types, and examples.
  Types such as `Setting`, `Codec`, `StorageKey`, and `Plan` describe library
  records, not Nix language types. See `settings/settings.nix` for their
  contracts
*/
{ lib, settingsScripts }:
{
  defaults = import ./defaults/defaults.nix { inherit lib; };
  options = import ./options.nix { inherit lib; };
  paths = import ./paths.nix { inherit lib; };
  settings = import ./settings/settings.nix { inherit lib settingsScripts; };
  shell = import ./shell.nix { inherit lib; };
  types = import ./types.nix { inherit lib; };
  zsh = import ./zsh.nix { inherit lib; };
}

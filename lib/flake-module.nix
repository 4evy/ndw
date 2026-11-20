{ lib, ... }:
{
  options.flake.darwinConfigurations = lib.options.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Darwin system configurations.";
  };
}

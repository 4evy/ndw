{
  config,
  lib,
  pkgs,
  specialArgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.nixpkgs;
  # Match NixOS and Home Manager's Nixpkgs configuration merge semantics
  callConfig = value: if lib.trivial.isFunction value then value { inherit lib pkgs; } else value;
  mergeConfig =
    lhs: rhs:
    lib.attrsets.recursiveUpdate lhs rhs
    // lib.attrsets.optionalAttrs (lhs ? allowUnfreePackages) {
      allowUnfreePackages = lhs.allowUnfreePackages ++ (rhs.allowUnfreePackages or [ ]);
    }
    //
      lib.attrsets.genAttrs
        (builtins.filter (name: builtins.hasAttr name lhs) [
          "packageOverrides"
          "perlPackageOverrides"
        ])
        (
          name: packages:
          let
            call = value: if lib.trivial.isFunction value then value packages else value;
          in
          call lhs.${name} // call (rhs.${name} or { })
        );
  configType = lib.types.mkOptionType {
    name = "nixpkgs-config";
    description = "Nixpkgs configuration";
    check = value: builtins.isAttrs value || lib.trivial.isFunction value;
    merge = _: lib.lists.foldr (definition: mergeConfig (callConfig definition.value)) { };
  };
  created = import cfg.source {
    inherit (cfg) config overlays;
    system = "aarch64-darwin";
  };
in
{
  options.nixpkgs = {
    source = lib.options.mkOption {
      type = lib.types.path;
      description = "Nixpkgs source supplied by the flake input.";
    };
    pkgs = lib.darwin.options.mkNullableOption lib.types.pkgs "Optional existing aarch64-darwin package set.";
    config = mkDefaultOption configType { } ''
      Settings passed when importing Nixpkgs, as an attribute set or a
      function accepting lib and pkgs. Definitions merge recursively,
      allowUnfreePackages lists concatenate, and package override functions
      compose by merging their results.
    '';
    overlays = mkDefaultOption (lib.types.listOf (
      lib.types.functionTo (lib.types.functionTo lib.types.attrs)
    )) [ ] "Overlays applied when importing the Nixpkgs flake input.";
  };
  config = {
    # Set the priority before forcing the package set so overrides stay lazy
    _module.args.pkgs = lib.modules.mkOverride lib.modules.defaultOverridePriority (
      if cfg.pkgs == null then created else cfg.pkgs
    );
    assertions = [
      {
        assertion = !(specialArgs ? pkgs);
        message = "Use nixpkgs.pkgs or the system function's pkgs argument instead of special.args.pkgs so package configuration is checked";
      }
      {
        assertion = cfg.pkgs == null || (cfg.config == { } && cfg.overlays == [ ]);
        message = "Pass nixpkgs.config and overlays when creating an external package set";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
        message = "The Darwin package set must target aarch64-darwin";
      }
    ];
  };
}

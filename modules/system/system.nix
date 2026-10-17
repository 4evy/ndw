{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.system;
in
{
  options = {
    system = {
      build = lib.options.mkOption {
        type = lib.types.lazyAttrsOf lib.types.unspecified;
        default = { };
        internal = true;
      };
      label = mkDefaultOption lib.types.str "darwin" "Name of the built system.";
      revision = lib.darwin.options.mkNullableOption lib.types.str "Source revision of this Darwin implementation.";
      configuration.revision = lib.darwin.options.mkNullableOption lib.types.str "Revision of the configuration flake.";
      primary.user = lib.darwin.options.mkNullableOption lib.types.str "Existing user whose settings and launchd agents are managed.";
      profile =
        mkDefaultOption lib.types.path "/nix/var/nix/profiles/system"
          "Profile used for system generations.";
    };
  };
  config = {
    environment.system.packages = lib.attrsets.attrValues {
      darwin = pkgs.callPackage ../../rebuild/rebuild.nix {
        inherit lib;
        profile = cfg.profile;
        nixPath = lib.strings.makeBinPath config.environment.profiles;
      };
    };
    system.build.toplevel = lib.asserts.checkAssertWarn config.assertions config.warnings (
      pkgs.linkFarm cfg.label {
        sw = cfg.build.environment;
        Applications = "${cfg.build.applications}/Applications";
        "applications.json" = cfg.build.applicationManifest;
        etc = cfg.build.files;
        launchd = cfg.build.launchd;
        activate = lib.meta.getExe cfg.build.activation;
        "files.json" = cfg.build.manifest;
        "metadata.json" = (pkgs.formats.json { }).generate "metadata.json" {
          inherit (cfg) label revision;
          configuration = cfg.configuration.revision;
          nixpkgs = config.nixpkgs.source.rev or null;
        };
      }
    );
  };
}

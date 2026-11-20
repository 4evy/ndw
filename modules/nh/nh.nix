{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption mkNullableOption;
  cfg = config.programs.nh;
  launchdOptions = import ../launchd/options.nix {
    inherit lib;
    plistType = (pkgs.formats.plist { }).type;
  };
  nixBin =
    if config.determinateNix.enable then
      "${config.determinateNix.package}/bin"
    else
      "/nix/var/nix/profiles/default/bin";
in
{
  options.programs.nh = {
    enable = lib.options.mkEnableOption "nh, a Nix CLI helper";
    package = lib.options.mkPackageOption pkgs "nh" { };
    flake = mkNullableOption lib.types.nonEmptyStr ''
      Default flake reference for nh, exported as NH_FLAKE. Command-specific
      variables such as NH_DARWIN_FLAKE take precedence.
    '';
    clean = {
      enable = lib.options.mkEnableOption ''
        scheduled pruning of `system.profile` generations and Nix store garbage
        collection. Does not prune user profiles or sweep foreign GC roots
      '';
      interval = mkDefaultOption launchdOptions.options.StartCalendarInterval.type [
        {
          Weekday = 7;
          Hour = 3;
          Minute = 15;
        }
      ] "Native launchd calendar schedule for system profile cleanup.";
      keep.count = mkDefaultOption lib.types.ints.positive 5 ''
        Minimum number of newest system generations to keep. The selected
        generation is also kept, even after a rollback.
      '';
      keep.since = mkDefaultOption lib.types.nonEmptyStr "7d" ''
        Keep system generations no older than this nh duration, even if that
        exceeds the minimum number of generations.
      '';
    };
  };

  config = lib.modules.mkMerge [
    (lib.modules.mkIf cfg.enable {
      environment.system.packages = [ cfg.package ];
      environment.variables = lib.modules.mkIf (cfg.flake != null) {
        NH_FLAKE = cfg.flake;
      };
    })
    (lib.modules.mkIf cfg.clean.enable {
      assertions = [
        {
          assertion = lib.strings.versionAtLeast (lib.strings.getVersion cfg.package) "4.5.0";
          message = "programs.nh.clean requires nh 4.5.0 or newer to preserve the selected generation.";
        }
      ];
      launchd.daemons.nh-clean = {
        enable = true;
        environment.variables = {
          HOME = "/var/root";
          NH_ASK = "0";
          PATH = "${nixBin}:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        script = ''
          # Serialize generation pruning with ndw activation, not store GC
          ${lib.meta.getExe pkgs.flock} --exclusive /nix/var/nix/darwin-activation.lock \
            ${lib.strings.escapeShellArgs [
              (lib.meta.getExe cfg.package)
              "clean"
              "profile"
              "--no-gc"
              "--keep"
              (toString cfg.clean.keep.count)
              "--keep-since"
              cfg.clean.keep.since
              "--"
              (toString config.system.profile)
            ]}
          exec nix --extra-experimental-features nix-command store gc
        '';
        config = {
          StartCalendarInterval = lib.modules.mkDefault cfg.clean.interval;
          StandardErrorPath = "/var/log/nh-clean.log";
        };
      };
    })
  ];
}

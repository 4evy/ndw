{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.security.pam.services.sudo_local;
  touchIdRule = "auth       sufficient     pam_tid.so";
  # Recognize only Apple's exact template, with or without Touch ID enabled
  appleTemplate = rule: ''
    # sudo_local: local config file which survives system update and is included for sudo
    # uncomment following line to enable Touch ID for sudo
    ${rule}
  '';
in
{
  imports = [
    (lib.modules.mkAliasOptionModule
      [ "security" "pam" "enableSudoTouchIdAuth" ]
      [
        "security"
        "pam"
        "services"
        "sudo_local"
        "touchIdAuth"
      ]
    )
  ];

  options.security.pam.services.sudo_local = {
    enable = mkDefaultOption lib.types.bool (cfg.text != "") ''
      Manage /etc/pam.d/sudo_local. Enabled by default when any rules are set.
    '';
    text = mkDefaultOption lib.types.lines "" "Additional rules for sudo_local.";
    touchIdAuth = lib.options.mkEnableOption "Touch ID authentication for sudo";
    reattach = lib.options.mkEnableOption ''
      reattaching sudo to the graphical login session so Touch ID can work
      from tmux or screen
    '';
    watchIdAuth = lib.options.mkEnableOption "Apple Watch authentication for sudo via pam-watchid";
  };

  config = {
    security.pam.services.sudo_local.text = lib.modules.mkBefore (
      lib.strings.concatLines (
        lib.lists.optional cfg.reattach "auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so"
        ++ lib.lists.optional cfg.touchIdAuth touchIdRule
        ++ lib.lists.optional cfg.watchIdAuth "auth       sufficient     ${pkgs.pam-watchid}/lib/pam_watchid.so"
      )
    );
    environment.files."pam.d/sudo_local" = lib.modules.mkIf cfg.enable {
      inherit (cfg) text;
      known.hashes = map (builtins.hashString "sha256") [
        (appleTemplate "#${touchIdRule}")
        (appleTemplate touchIdRule)
        (touchIdRule + "\n")
      ];
    };
    system.activation.steps.files.checks = lib.modules.mkIf cfg.enable (
      lib.modules.mkBefore ''
        if ! /usr/bin/grep -Eq '^[[:blank:]]*auth[[:blank:]]+include[[:blank:]]+sudo_local([[:blank:]]|$)' /etc/pam.d/sudo; then
          printf >&2 'error: /etc/pam.d/sudo does not include sudo_local. Restore the Apple sudo policy before enabling ndw PAM rules.\n'
          exit 2
        fi
      ''
    );
  };
}

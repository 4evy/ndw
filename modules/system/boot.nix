# Adapted from nix-darwin's modules/services/activate-system/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  launchd.daemons.activate-system = {
    enable = true;
    load.on.activation = false;
    path = lib.attrsets.attrValues { inherit (pkgs) coreutils; };
    environment.variables = {
      USER = "root";
      LOGNAME = "root";
      HOME = "/var/root";
      MAIL = "/var/mail/root";
      SHELL = lib.meta.getExe pkgs.bash;
      LANG = "C";
      LC_CTYPE = "UTF-8";
    };
    script = ''
      # A failed attempt must never become the successful system after reboot
      # Direct activation also advances this marker without adding a profile
      # generation, so it remains selected after a normal reboot
      # Restore core files without running rebuild hooks or Homebrew at boot
      # Pending launchd changes are reconciled by an explicit retry or rollback
      # TODO: Verify real boot ordering and APFS /run creation after a reboot
      selected=/nix/var/nix/gcroots/darwin/current
      if [[ ! -e $selected ]]; then selected=${lib.strings.escapeShellArg config.system.profile}; fi
      systemConfig=$(readlink --canonicalize -- "$selected")

      if /usr/bin/grep -Fqx '# darwin: boot-aware activation' "$systemConfig/activate"; then
        exec "$systemConfig/activate" --boot
      fi
      # Legacy generations have no selective boot mode. Restore their pointers
      # without running arbitrary rebuild hooks during early boot
      ln --symbolic --force --no-target-directory -- "$systemConfig" /run/current-system
      if [[ -d /nix/var/nix/gcroots ]]; then
        ln --symbolic --force --no-target-directory -- /run/current-system /nix/var/nix/gcroots/current-system
      fi
    '';
    config = {
      RunAtLoad = true;
      # Mount and activation-lock races must not leave recovery failed for
      # the entire boot. launchd throttles retries until restoration succeeds
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 30;
      StandardOutPath = "/var/log/darwin-activation.log";
      StandardErrorPath = "/var/log/darwin-activation.log";
    };
  };
}

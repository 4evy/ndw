# Adapted from nix-darwin's modules/services/activate-system/default.nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  paths = import ./activation/paths.nix;
in
{
  launchd.daemons.activate-system = {
    enable = true;
    load.on.activation = false;
    path = lib.attrsets.attrValues { inherit (pkgs) coreutils flock; };
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
      activation_state=${lib.strings.escapeShellArg paths.state}
      profile=${lib.strings.escapeShellArg config.system.profile}
    ''
    + builtins.readFile ./activation/recovery.sh
    + ''
      systemConfig=$(activation_recovery_system "$profile")
      if /usr/bin/grep -Fqx '# darwin: boot-aware activation' "$systemConfig/activate"; then
        # The activator revalidates the selection under its lock
        exec "$systemConfig/activate" --boot
      fi

      # Legacy generations have no selective boot mode. Restore their
      # pointers without running arbitrary rebuild hooks during early boot
      umask 0022
      exec 9>>${lib.strings.escapeShellArg paths.lock}
      ${lib.darwin.shell.failIf "! flock --exclusive --nonblock 9" "another Darwin activation is in progress"}
      ${lib.darwin.shell.failIf ''[[ $(activation_recovery_system "$profile") != "$systemConfig" ]]'' "the recovery target changed"}
      ln --symbolic --force --no-target-directory -- "$systemConfig" /run/current-system
      ln --symbolic --force --no-target-directory -- /run/current-system "''${activation_state%/*}/current-system"
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

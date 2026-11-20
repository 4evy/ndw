{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.shell) failIf;
in
{
  system.activation.steps.run = {
    on.boot = true;
    checks = ''
      macos_version=$(/usr/bin/sw_vers -productVersion)
      ${failIf ''[[ ! $macos_version =~ ^[0-9]+(\.[0-9]+)*$ ]] || (( ''${macos_version%%.*} < 27 ))'' "activation requires macOS 27 or newer"}
      ${failIf "[[ $(/usr/sbin/sysctl -n hw.optional.arm64) != 1 ]]" "activation requires Apple Silicon"}
      ${failIf "[[ ( -e /etc/synthetic.conf || -L /etc/synthetic.conf ) && ! -f /etc/synthetic.conf ]]" "/etc/synthetic.conf must be a regular file"}
      ${failIf "[[ ( -e /run || -L /run ) && ( ! -L /run || $(readlink --canonicalize -- /run) != /private/var/run ) ]]" "existing /run must resolve to /private/var/run"}
      run_configured=false
      for manifest in /etc/synthetic.conf /etc/synthetic.d/*; do
        if [[ ! -f $manifest ]]; then continue; fi
        while IFS= read -r line || [[ -n $line ]]; do
          case $line in
          run|run[$'\t ']* )
            run_target=''${line#*$'\t'}
            if [[ $run_configured == true || $line != run$'\t'* || "/''${run_target#/}/" == /run/* || $(readlink --canonicalize -- "/''${run_target#/}") != /private/var/run ]]; then
              printf >&2 'error: conflicting or duplicate run entry in %s\n' "$manifest"
              exit 2
            fi
            run_configured=true
            ;;
          esac
        done < "$manifest"
      done
      if [[ $run_configured == false ]]; then
        ${failIf "[[ ( -e /etc/synthetic.d || -L /etc/synthetic.d ) && ( ! -d /etc/synthetic.d || -L /etc/synthetic.d ) ]]" "/etc/synthetic.d must be a directory, not a symlink"}
        ${failIf "[[ -e /etc/synthetic.d/darwin.conf || -L /etc/synthetic.d/darwin.conf ]]" "refusing to overwrite an unrelated /etc/synthetic.d/darwin.conf"}
      fi
    ''
    + lib.strings.optionalString (config.system.primary.user != null) (
      lib.strings.escapeShellArgs [
        "id"
        "--"
        config.system.primary.user
      ]
      + " >/dev/null"
    );
    text = ''
      if [[ $run_configured == false ]]; then
        mkdir --parents -- /etc/synthetic.d
        install --mode=644 --no-target-directory -- ${pkgs.writeText "darwin-synthetic.conf" "run\tprivate/var/run\n"} /etc/synthetic.d/darwin.conf
      fi
      ${failIf "[[ ! -L /run ]] && ! /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t" "could not synthesize /run, a reboot may be required"}
      ${failIf "[[ ! -L /run || $(readlink --canonicalize -- /run) != /private/var/run ]]" "/run must resolve to /private/var/run"}
    '';
  };
}

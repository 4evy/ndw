{
  lib,
  coreutils,
  diffutils,
  jq,
  writeShellApplication,
  functions,
  user,
  environment,
  jobs,
}:
let
  q = lib.strings.escapeShellArg;
  agents = lib.lists.filter (
    item: item.kind == "agents" && item.user == user && item.domain == "user"
  ) jobs;
in
writeShellApplication {
  name = "darwin-login-restore";
  # Configured values are literal, including dollar signs and backticks
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = lib.attrsets.attrValues (
    { inherit coreutils; } // lib.attrsets.optionalAttrs (agents != [ ]) { inherit diffutils jq; }
  );
  text = ''
    user=${q user}
    # A newer helper may be restoring a generation with a different owner
    if [[ ''${1:-} != "$user" || -z $user ]]; then exit 0; fi
    uid=$(id --user)
    ${lib.darwin.shell.failIf ''[[ $(id --user -- "$user") != "$uid" ]]'' "login restoration must run as the configured user"}
  ''
  + lib.strings.optionalString (environment != { }) ''
    changed=false
    ${lib.strings.concatMapAttrsStringSep "\n" (key: value: ''
      # A sentinel distinguishes unset values and preserves trailing newlines
      if ! stored=$(/bin/launchctl getenv ${q key} && printf .) \
        || [[ $stored != ${q (value + "\n.")} ]]; then
        /bin/launchctl setenv ${q key} ${q value}
        changed=true
      fi
    '') environment}
    if [[ $changed == true ]]; then
      /usr/bin/killall -qu "$user" Dock || true
    fi
  ''
  + lib.strings.optionalString (agents != [ ]) ''
    ${functions.equal}
    ${functions.home}
    home=$(launchd_home "$user")
    missing=false
    ${lib.strings.concatMapStringsSep "\n" (item: ''
      target="$home"/${q "Library/LaunchAgents/${item.label}.plist"}
      # The home directory may become available after boot restoration
      if [[ ! -e $target && ! -L $target ]]; then
        printf >&2 'warning: waiting for missing job %s during user restoration\n' "$target"
        missing=true
      elif ! launchd_equal ${q item.source} "$target"; then
        # Preserve local edits and files left by an uncommitted activation
        printf >&2 'warning: keeping modified job %s during user restoration\n' "$target"
      elif ! /bin/launchctl print "user/$uid"/${q item.label} >/dev/null 2>&1; then
        /bin/launchctl bootstrap "user/$uid" "$target"
      fi
    '') agents}
    if [[ $missing == true ]]; then exit 1; fi
  '';
}

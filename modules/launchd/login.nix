{
  lib,
  coreutils,
  diffutils,
  flock,
  jq,
  writeShellApplication,
  functions,
  user,
}:
let
  shell = lib.darwin.shell;
in
writeShellApplication {
  name = "darwin-login";
  runtimeInputs = lib.attrsets.attrValues {
    inherit
      coreutils
      diffutils
      flock
      jq
      ;
  };
  text =
    functions.equal
    + functions.home
    + ''
      user=${lib.strings.escapeShellArg user}
      uid=$(id --user)
      ${lib.darwin.shell.failIf ''[[ $(id --user -- "$user") != "$uid" ]]'' "login restoration must run as the configured user"}
      # Activation and login must not publish different generations together
      exec 9</nix/var/nix/darwin-activation.lock
      ${lib.darwin.shell.failIf "! flock --exclusive --nonblock 9" "activation is in progress, retrying login restoration later"}
      (
        selected=/nix/var/nix/gcroots/darwin/current
        ${shell.failIf "[[ ! -d $selected ]]" "no successful Darwin activation is available for login restoration"}
        system=$(readlink --canonicalize-existing -- "$selected")
        ${shell.failIf ''[[ $(readlink --canonicalize-existing -- /run/current-system) != "$system" ]]'' "core runtime links are not ready for user restoration"}
        # Use the successful generation's evaluated plan, even when this
        # helper was installed by an activation that subsequently failed
        if [[ -x $system/launchd/restore ]]; then
          exec "$system/launchd/restore" "$user"
        fi
        # Compatibility with generations built before restore was generated
        # An old generation may not have manifests for this recovery protocol
        if [[ ! -f $system/launchd/jobs.json || ! -f $system/launchd/environment.json ]]; then
          exit 0
        fi
        environment=$(jq --compact-output --arg user "$user" \
          'if .owner == $user then .user else {} end' "$system/launchd/environment.json")
        changed=false
        while IFS= read -r -d "" key && IFS= read -r -d "" value; do
          # Keep the sentinel so empty values and trailing newlines stay distinct
          if ! stored=$(/bin/launchctl getenv "$key" && printf .) \
                      || [[ $stored != "$value"$'\n.' ]]; then
            /bin/launchctl setenv "$key" "$value"
            changed=true
          fi
        done < <(jq --raw-output0 'to_entries[] | .key, .value' <<< "$environment")
        if [[ $changed == true ]]; then
          /usr/bin/killall -qu "$user" Dock || true
        fi
        jobs=$(jq --compact-output --arg user "$user" '
          [.[] | select(.kind == "agents" and .user == $user and .domain == "user")]
        ' "$system/launchd/jobs.json")
        home=
        if [[ $jobs != '[]' ]]; then
          home=$(launchd_home "$user")
        fi
        missing=false
        while IFS= read -r -d "" label && IFS= read -r -d "" source; do
          target="$home/Library/LaunchAgents/$label.plist"
          # The home directory may become available after boot restoration
          if [[ ! -e $target && ! -L $target ]]; then
            printf >&2 'warning: waiting for missing job %s during user restoration\n' "$target"
            missing=true
            continue
          fi
          # Preserve local edits and files left by an uncommitted activation
          if ! launchd_equal "$source" "$target"; then
            printf >&2 'warning: keeping modified job %s during user restoration\n' "$target"
            continue
          fi
          if ! /bin/launchctl print "user/$uid/$label" >/dev/null 2>&1; then
            /bin/launchctl bootstrap "user/$uid" "$target"
          fi
        done < <(jq --raw-output0 '.[] | .label, .source' <<< "$jobs")
        if [[ $missing == true ]]; then exit 1; fi
      ) 9>&-
    '';
}

{
  equal = ''
    launchd_equal() {
      local left=$1 right=$2 left_json right_json
      if cmp --silent -- "$left" "$right"; then
        return 0
      fi
      if [[ ! -f $left || ! -f $right ]]; then
        return 1
      fi
      # Dictionary order and XML formatting do not change plist behavior
      left_json=$(/usr/bin/plutil -convert json -o - -- "$left" 2>/dev/null |
        jq --sort-keys --compact-output .) || return 1
      right_json=$(/usr/bin/plutil -convert json -o - -- "$right" 2>/dev/null |
        jq --sort-keys --compact-output .) || return 1
      [[ $left_json == "$right_json" ]]
    }
  '';
  installed = ''
    launchd_installed() {
      local source=$1 target=$2 owner=$3
      if [[ ! -f $target || -L $target ]]; then return 1; fi
      if [[ $(stat --format=%u -- "$target") != "$owner" \
        || $(stat --format=%a -- "$target") != 644 ]]; then
        return 1
      fi
      launchd_equal "$source" "$target"
    }
  '';
  home = ''
    launchd_home() {
      local user=$1 record homes home candidate canonical
      record=''${user//\\/\\\\}
      record=''${record//\//\\/}
      # dscl's text format changes when a value contains spaces
      if ! homes=$(/usr/bin/dscl -plist /Search -read "/Users/$record" NFSHomeDirectory |
        /usr/bin/plutil -convert json -o - -- - |
        jq --exit-status --raw-output '
                      .["dsAttrTypeStandard:NFSHomeDirectory"]
                      | arrays | select(length > 0)
                      | select(all(.[]; type == "string" and startswith("/")
                          and length > 1
                          and (contains("\n") or contains("\u0000") | not)))
                      | .[]
                    '); then
        printf >&2 'error: cannot read an absolute home directory for user %s\n' "$user"
        return 2
      fi
      # Directory Services can return equivalent aliases such as /var/root
      # and /private/var/root for the same account
      home=
      canonical=
      while IFS= read -r candidate; do
        if [[ -z $home ]]; then
          home=$candidate
          canonical=$(readlink --canonicalize-missing -- "$home") || return
        else
          if [[ $(readlink --canonicalize-missing -- "$candidate") != "$canonical" ]]; then
            printf >&2 'error: conflicting home directories for user %s\n' "$user"
            return 2
          fi
        fi
      done <<<"$homes"
      printf '%s\n' "$home"
    }
  '';
}

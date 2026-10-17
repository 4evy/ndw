{
  lib,
  pkgs,
  plan,
}:
let
  command = lib.strings.escapeShellArgs;
  probe = pkgs.writeShellApplication {
    name = "darwin-probe-application";
    runtimeInputs = lib.attrsets.attrValues { inherit (pkgs) coreutils; };
    text = ''
      temporary=$(mktemp --tmpdir="$1" .darwin-permission.XXXXXXXX)
      trap 'rm --force -- "$temporary"' EXIT
    '';
  };
  sync =
    command (
      [
        (lib.meta.getExe pkgs.rsync)
      ]
      ++ map (flag: "--${flag}") [
        "recursive"
        "links"
        "perms"
        "specials"
        "checksum"
        "owner"
        "group"
        "copy-unsafe-links"
        "delete-delay"
        "delete-missing-args"
        "force"
        "from0"
        "no-implied-dirs"
        "chmod=-w"
      ]
    )
    + " "
    + ''--chown="$uid:$gid" --files-from="$work/names" -- "$source/" "$destination/"'';
in
{
  prepare = ''
    # Native find and xargs propagate a failed permission probe before activation
    jq --raw-output0 '[.[].probes[]] | unique[]' <<< "$applications_plan" \
      | xargs --null --no-run-if-empty -I{} find '{}' -type d -name '*.app' -prune -print0 \
      | xargs --null --no-run-if-empty --max-args=1 ${lib.meta.getExe probe}
  '';
  text = ''
    (
      work=$(mktemp --directory --tmpdir darwin-applications.XXXXXXXX)
      staging=""
      trap 'rm --recursive --force -- "$work"; if [[ -n $staging ]]; then rm --recursive --force -- "$staging"; fi' EXIT
      ${plan.readRecords
        {
          source = ".source";
          target = ".target";
          uid = ".uid | tostring";
          gid = ".gid | tostring";
          names = ".names | tojson";
        }
        "$applications_plan"
        ''
          jq --null-input --raw-output0 --argjson names "$names" '$names[]' > "$work/names"
          parent=$(dirname -- "$target")
          if ${plan.legacyLink ''"$parent"''}; then rm -- "$parent"; fi
          ${lib.darwin.shell.failIf ''[[ -L $parent || ! -d $(dirname -- "$parent") ]]'' "application parent was replaced or its home is unavailable"}
          if [[ ! -d $parent ]]; then install --directory --mode=755 --owner="$uid" --group="$gid" -- "$parent"; fi
          destination=$target
          if ${plan.legacyLink ''"$target"''}; then
            staging=$(mktemp --directory --tmpdir="$parent" '.Nix Apps.XXXXXXXX')
            destination=$staging
          elif [[ -L $target ]]; then
            ${lib.darwin.shell.fail "error: application destination was replaced with an unrelated symlink"}
          fi
          if [[ ! -d $destination ]]; then install --directory --mode=755 --owner="$uid" --group="$gid" -- "$destination"; fi
          printf >&2 'setting up %s...\n' "$target"
          ${sync}
          if [[ $destination != "$target" ]]; then
            chmod 755 -- "$destination"
            chown "$uid:$gid" -- "$destination"
            rm -- "$target"
            mv --no-copy --no-target-directory -- "$destination" "$target"
            staging=""
          fi
        ''
      }
    )
  '';
}

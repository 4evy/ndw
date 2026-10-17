{
  lib,
  coreutils,
  writeShellApplication,
}:
writeShellApplication {
  name = "launchd-install";
  runtimeInputs = lib.attrsets.attrValues { inherit coreutils; };
  text = ''
    if [[ $# != 2 ]]; then
      printf >&2 'usage: launchd-install SOURCE TARGET\n'
      exit 2
    fi
    source=$1
    target=$2
    directory=$(dirname -- "$target")
    temporary=$(mktemp --tmpdir="$directory" .darwin-plist.XXXXXXXXXX)
    trap 'rm --force -- "$temporary"' EXIT
    install --mode=644 --no-target-directory -- "$source" "$temporary"
    # A login scan must see a complete old or new plist
    mv --force --no-copy --no-target-directory -- "$temporary" "$target"
  '';
}

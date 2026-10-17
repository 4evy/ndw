{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  files = lib.attrsets.filterAttrs (_: file: file.enable) config.environment.files;
  lines = lib.strings.concatStringsSep "\n";
  command = lib.strings.escapeShellArgs;
  backupSuffixes = [
    ".before darwin"
    ".before-nix-darwin"
    ".orig"
  ];
  parents =
    directory:
    lib.lists.optionals (directory != "/etc" && directory != "/") (
      [ directory ] ++ parents (dirOf directory)
    );
  # Keep the deployment layout and replacement policy in the evaluated plan
  plan = lib.attrsets.mapAttrsToList (name: file: {
    destination = "/etc/${name}";
    directory = dirOf "/etc/${name}";
    link = "/etc/static/${name}";
    backup = "/etc/${name}.before darwin";
    hashes = file.known.hashes;
    template = "/System/Library/Templates/Data/private/etc/${name}";
    inherit (file.known) macOS;
  }) files;
  check = file: ''
    (
      ${lib.strings.toShellVars {
        inherit (file) destination link backup;
      }}
      ${lib.strings.concatMapStringsSep "\n" (directory: ''
        if [[ -L ${command [ directory ]} ]]; then
          if [[ $(readlink -- ${command [ directory ]}) == ${
            command [ "/etc/static/${lib.strings.removePrefix "/etc/" directory}" ]
          } ]] \
            && jq --exit-status --arg target ${command [ (lib.strings.removePrefix "/etc/" directory) ]} \
              'index($target) != null' <<< "$files_previous_targets" >/dev/null; then
            files_no_backup ${command [ directory ]}
            # Pruning removes this owned parent before installing children
            exit 0
          fi
          printf >&2 'error: parent of managed file is an unmanaged symlink: %s\n' ${command [ directory ]}
          exit 2
        fi
        if [[ ( -e ${command [ directory ]} || -L ${command [ directory ]} ) && ! -d ${command [ directory ]} ]]; then
          printf >&2 'error: parent of managed file is not a directory: %s\n' ${command [ directory ]}
          exit 2
        fi
      '') (lib.lists.reverseList (parents file.directory))}
      if [[ ! -e $destination && ! -L $destination ]]; then exit 0; fi
      if [[ $(readlink -- "$destination") == "$link" ]]; then exit 0; fi
      if [[ ( -e $backup || -L $backup ) && ! -f $backup && ! -L $backup ]]; then
        printf >&2 'error: backup of managed file is not a file: %s\n' "$backup"
        exit 2
      fi
      if [[ -d $destination && ! -L $destination ]]; then
        files_check_directory "$destination"
        exit 0
      fi
      ${lib.strings.optionalString file.macOS ''
        # Compare with the running OS, including versions newer than this build
        if [[ -f $destination && ! -L $destination && -f ${command [ file.template ]} ]] \
          && cmp --silent -- "$destination" ${command [ file.template ]}; then
          exit 0
        fi
      ''}
      ${lib.strings.optionalString (file.hashes != [ ]) ''
        if [[ -f $destination && ! -L $destination ]]; then
          hash=$(sha256sum < "$destination")
          case ''${hash%% *} in
          ${lib.strings.concatMapStringsSep " | " lib.strings.escapeShellArg file.hashes}) exit 0 ;;
          esac
        fi
      ''}
      printf >&2 'error: refusing to overwrite unmanaged file %s\n' "$destination"
      exit 2
    )
  '';
  install =
    file:
    command [
      "files_install"
      file.destination
      file.directory
      file.link
      file.backup
    ];

in
{
  options.environment.files = lib.options.mkOption {
    default = { };
    description = ''
      Files deployed in /etc. Existing unrecognized content is preserved

      Recognized replacements are saved at `PATH.before darwin`. Earlier
      backups are retained with numbered suffixes after repeated OS updates.
      When a managed file is removed or disabled, its latest saved original
      is restored if the installed symlink still belongs to Darwin. Legacy
      `.before-nix-darwin` and `.orig` backups are also recognized. Unrecognized
      local replacements and their backups are left untouched

      A managed link can become a directory of managed files when it has no
      saved original to restore. Other symlink parents are rejected to avoid
      installing files through them. A directory containing only previous
      managed links and their parent directories can become a managed link
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }: {
          options = {
            enable = mkDefaultOption lib.types.bool true "Whether to deploy this file.";
            text = mkDefaultOption lib.types.lines "" "Text of the managed file.";
            source =
              mkDefaultOption lib.types.path (pkgs.writeText "file" config.text)
                "Source deployed instead of text."
              // {
                defaultText = lib.options.literalExpression ''pkgs.writeText "file" config.text'';
              };
            known.hashes =
              mkDefaultOption (lib.types.listOf lib.types.str) [ ]
                "SHA-256 hashes of existing files that may be backed up and replaced.";
            known.macOS = mkDefaultOption lib.types.bool false ''
              Also recognize regular files identical to the running macOS
              template in /System/Library/Templates/Data/private/etc. This
              permits recovery after an OS update introduces a new baseline
              without accepting local edits or arbitrary symlinks.
            '';
          };
        }
      )
    );
  };
  config = {
    assertions = lib.attrsets.mapAttrsToList (name: _: {
      assertion =
        lib.darwin.paths.isRelativeFile name
        && name != "static"
        && !lib.strings.hasPrefix "static/" name
        && !lib.lists.any (parent: lib.strings.hasPrefix "${parent}/" name) (builtins.attrNames files);
      message = "environment.files.${name} must be a relative path outside static/, without traversal or another managed file as a parent";
    }) files;
    system.build.files = pkgs.linkFarm "etc" (lib.attrsets.mapAttrs (_: file: file.source) files);
    system.build.manifest = (pkgs.formats.json { }).generate "files.json" (
      lib.attrsets.mapAttrs (_: file: toString file.source) files
    );
    system.activation.steps.files = {
      deps = [ "run" ];
      on.boot = true;
      runtimeInputs = lib.attrsets.attrValues {
        inherit (pkgs) diffutils findutils jq;
      };
      checks = ''
        if [[ ( -e /etc/static || -L /etc/static ) && ! -L /etc/static ]]; then
          printf >&2 'error: /etc/static must be a symlink\n'
          exit 2
        fi
        files_previous_targets='[]'
        for previous_system in "''${activation_previous_systems[@]}"; do
          if [[ -f $previous_system/files.json ]]; then
            previous_targets=$(jq --compact-output 'keys' "$previous_system/files.json")
          elif [[ -d $previous_system/etc ]]; then
            # -H follows the immutable tree root, but not directory entries
            previous_targets=$(find -H "$previous_system/etc" -type l -printf '%P\0' \
              | jq --raw-input --slurp --compact-output 'split("\u0000")[:-1]')
          else
            continue
          fi
          files_previous_targets=$(jq --compact-output --argjson previous "$previous_targets" \
            '. + $previous | unique' <<< "$files_previous_targets")
        done
      ''
      + lines (map check plan);
      functions = ''
        files_no_backup() {
          local destination=$1 backup
          ${lib.strings.concatMapStringsSep "\n" (suffix: ''
            backup=$destination${lib.strings.escapeShellArg suffix}
            if [[ -e $backup || -L $backup ]]; then
              printf >&2 'error: cannot change managed file layout while its backup exists: %s\n' "$backup"
              return 2
            fi
          '') backupSuffixes}
        }
        files_check_directory() {
          local destination=$1 entries entry target
          # Capture the inventory first so traversal failures abort preflight
          entries=$(find "$destination" -print0 \
            | jq --raw-input --slurp --compact-output 'split("\u0000")[:-1]') || return
          while IFS= read -r -d "" entry; do
            target=''${entry#/etc/}
            if [[ -d $entry && ! -L $entry ]]; then
              if jq --exit-status --arg prefix "$target/" \
                'any(.[]; startswith($prefix))' <<< "$files_previous_targets" >/dev/null; then
                continue
              fi
            elif [[ $(readlink -- "$entry") == "/etc/static/$target" ]] \
              && jq --exit-status --arg target "$target" \
                'index($target) != null' <<< "$files_previous_targets" >/dev/null; then
              files_no_backup "$entry" || return
              continue
            fi
            printf >&2 'error: refusing to replace directory containing unmanaged content: %s\n' "$entry"
            return 2
          done < <(jq --join-output '.[] | ., "\u0000"' <<< "$entries")
        }
        files_install() {
          local destination=$1 directory=$2 link=$3 backup=$4
          mkdir --parents -- "$directory"
          if [[ $(readlink -- "$destination") == "$link" ]]; then return; fi
          if [[ -d $destination && ! -L $destination ]]; then
            # Pruning removed owned leaves. rmdir preserves unexpected content
            find "$destination" -depth -type d -exec rmdir -- {} +
          fi
          if [[ -e $destination || -L $destination ]]; then
            mv --backup=numbered --no-target-directory -- "$destination" "$backup"
          fi
          ln --symbolic --no-target-directory -- "$link" "$destination"
        }
        files_prune() {
          local target destination
          while IFS= read -r -d "" target; do
            destination=/etc/$target
            files_restore "$destination" "/etc/static/$target"
          done < <(jq --null-input --join-output --argjson previous "$files_previous_targets" \
            --argjson current ${command [ (builtins.toJSON (builtins.attrNames files)) ]} '
              $previous - $current | .[] | ., "\u0000"
            ')
        }
        files_restore() {
          local destination=$1 link=$2 backup directory
          directory=$(dirname -- "$destination")
          while [[ $directory != /etc && $directory != / ]]; do
            # A replaced parent must not redirect cleanup into another tree
            if [[ -L $directory ]]; then return; fi
            directory=$(dirname -- "$directory")
          done
          if [[ $(readlink -- "$destination") != "$link" ]]; then return; fi
          # A retained upstream link may outlive the first fork generation
          # Prefer this fork's backup, then current and older upstream names
          ${lib.strings.concatMapStringsSep "\n" (suffix: ''
            backup=$destination${lib.strings.escapeShellArg suffix}
            if [[ -f $backup || -L $backup ]]; then
              mv --no-target-directory -- "$backup" "$destination"
              return
            elif [[ -e $backup ]]; then
              printf >&2 'error: cannot restore a non-file backup: %s\n' "$backup"
              return 2
            fi
          '') backupSuffixes}
          rm -- "$destination"
        }
      '';
      text = lines (
        [
          "files_prune"
          ''ln --symbolic --force --no-target-directory -- "$system/etc" /etc/static''
        ]
        ++ map install plan
      );
    };
  };
}

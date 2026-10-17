{ lib, settingsScripts }:
let
  q = lib.escapeShellArg;
  plist = import ../plist.nix {
    inherit lib;
    tagged = true;
  };
  file = name: value: builtins.toFile name (plist.document value);
  choice = name: value: ''
    ${name}() {
      local destination=$1 data now ${
        lib.optionalString (value ? album && value.album != "") "identifier"
      }
      /bin/cat ${
        q (
          file "wallpaper-entry.plist" {
            Type = "linked";
            Linked.Content = {
              Choices = [
                {
                  Files = [ ];
                  Provider = value.provider;
                  Configuration._data = "";
                }
              ];
              Shuffle = "$null";
            };
          }
        )
      } > "$destination"
      ${lib.optionalString (value.configuration != null || (value ? album && value.album != "")) ''
        /bin/cat ${
          q (
            file "wallpaper-configuration.plist" (
              if value.configuration == null then { } else value.configuration
            )
          )
        } > "$work/configuration.plist"
        ${lib.optionalString (value ? album && value.album != "") (
          if builtins.match "[0-9A-Fa-f-]{36}" value.album != null then
            ''
              identifier=${q value.album}
            ''
          else
            ''
              # User startup files can change the result format or run queries
              if ! identifier=$(/usr/bin/sqlite3 -init /dev/null -batch -noheader -list -readonly \
                "$HOME/Pictures/Photos Library.photoslibrary/database/Photos.sqlite" \
                ${q "select ZUUID from ZGENERICALBUM where ZKIND = 2 and ZTRASHEDSTATE = 0 and ZTITLE = '${lib.replaceStrings [ "'" ] [ "''" ] value.album}' limit 1"}); then
                printf '%s\n' ${q "Couldn't read your Photos library to find album ${value.album}, give the terminal Full Disk Access or set the album's identifier"} >&2
                return 1
              fi
              if [ -z "$identifier" ]; then
                printf 'There is no album named %s in Photos\n' ${q value.album} >&2
                return 1
              fi
            ''
        )}
        ${lib.optionalString (value ? album && value.album != "") ''
          /usr/bin/plutil -replace identifier -string "$identifier" "$work/configuration.plist"
        ''}
        data=$(binary_data "$work/configuration.plist")
        /usr/bin/plutil -replace Linked.Content.Choices.0.Configuration -data "$data" "$destination"
      ''}
      data=$(binary_data ${q (file "wallpaper-options.plist" { values = value.options; })})
      /usr/bin/plutil -replace Linked.Content.EncodedOptionValues -data "$data" "$destination"
      now=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')
      /usr/bin/plutil -replace Linked.LastSet -date "$now" "$destination"
      /usr/bin/plutil -replace Linked.LastUse -date "$now" "$destination"
    }
  '';
in
wanted:
let
  spaces = lib.imap0 (at: item: item // { function = "wallpaper_space_${toString at}"; }) (
    lib.attrsToList (wanted.spaces or { })
  );
in
# Nested shell quoting triggers ShellCheck's single-quote heuristic
"# shellcheck disable=SC1003\n/bin/bash -euo pipefail -c "
+ q ''
  store="$HOME/Library/Application Support/com.apple.wallpaper/Store"
  /bin/mkdir -p "$store"
  work=$(/usr/bin/mktemp -d "$store/.darwin-settings.XXXXXXXX")
  trap '/bin/rm -rf "$work"' EXIT
  index=$work/Index.plist
  if [ -f "$store/Index.plist" ]; then
    /bin/cp "$store/Index.plist" "$index"
  else
    /usr/bin/plutil -create xml1 "$index"
  fi
  plist_read() {
    local text
    text=$(/usr/bin/plutil -extract "$1" raw -expect "$2" -n -o - "$3" && printf .) || return
    REPLY=''${text%.}
  }
  plist_copy() {
    local xml
    xml=$(/usr/bin/plutil -extract "$2" xml1 -o - "$1") || return
    /usr/bin/plutil -replace "$4" -xml "$xml" "$3"
  }
  binary_data() {
    /usr/bin/plutil -convert binary1 -o "$work/blob.plist" "$1" || return
    /usr/bin/base64 -b 0 < "$work/blob.plist"
  }
  ${lib.optionalString (wanted ? all) ''
    ${choice "wallpaper_all" wanted.all}
    wallpaper_all "$work/all.plist"
    xml=$(/usr/bin/plutil -convert xml1 -o - "$work/all.plist")
    /usr/bin/plutil -replace AllSpacesAndDisplays -xml "$xml" "$index"
    /usr/bin/plutil -replace SystemDefault -xml "$xml" "$index"
    /usr/bin/plutil -replace Displays -dictionary "$index"
    /usr/bin/plutil -replace Spaces -dictionary "$index"
  ''}
  ${lib.optionalString (wanted ? spaces) ''
    ${lib.concatMapStrings (item: choice item.function item.value) spaces}
    /bin/cp "$index" "$work/previous.plist"
    previous=$work/previous.plist
    if plist_read AllSpacesAndDisplays.Type string "$previous" 2>/dev/null && [ "$REPLY" = linked ]; then
      fallback=AllSpacesAndDisplays
    else
      fallback=SystemDefault
    fi
    /usr/bin/plutil -replace Spaces -dictionary "$index"
    seen=' '
    monitors=0
    if /usr/bin/defaults export com.apple.spaces "$work/desktops.plist" 2>/dev/null; then
      plist_read 'SpacesDisplayConfiguration.Management Data.Monitors' array "$work/desktops.plist"
      monitors=$REPLY
    fi
    # Mission Control starts Desktop numbering at 1 on each display
    for ((monitor = 0; monitor < monitors; monitor++)); do
      prefix="SpacesDisplayConfiguration.Management Data.Monitors.$monitor.Spaces"
      count=0 number=0
      if plist_read "$prefix" array "$work/desktops.plist" 2>/dev/null; then
        count=$REPLY
      fi
      for ((at = 0; at < count; at++)); do
        plist_read "$prefix.$at.type" integer "$work/desktops.plist"
        [ "$REPLY" = 0 ] || continue
        number=$((number + 1))
        seen="$seen$number "
        plist_read "$prefix.$at.uuid" string "$work/desktops.plist"
        uuid=''${REPLY//./\\.}
        /usr/bin/plutil -replace "Spaces.$uuid" -dictionary "$index"
        case "$number" in
          ${lib.concatMapStrings (item: ''
            ${q item.name})
              ${item.function} "$work/space.plist"
              xml=$(/usr/bin/plutil -convert xml1 -o - "$work/space.plist")
              /usr/bin/plutil -replace "Spaces.$uuid.Default" -xml "$xml" "$index"
              ;;
          '') spaces}
          *)
            if /usr/bin/plutil -type "Spaces.$uuid" "$previous" >/dev/null 2>&1; then
              plist_copy "$previous" "Spaces.$uuid.Default" "$index" "Spaces.$uuid.Default"
            else
              plist_copy "$previous" "$fallback" "$index" "Spaces.$uuid.Default"
            fi
            ;;
        esac
        /usr/bin/plutil -replace "Spaces.$uuid.Displays" -dictionary "$index"
      done
    done
    ${lib.concatMapStrings (item: ''
      case "$seen" in
        *${q " ${item.name} "}*) ;;
        *) printf 'darwin.settings: there is no Desktop %s in Mission Control, its wallpaper will be set once it exists and you rebuild\n' ${q item.name} >&2 ;;
      esac
    '') spaces}
    if ! plist_read SystemDefault.Type string "$previous" 2>/dev/null || [ "$REPLY" != linked ]; then
      plist_copy "$previous" "$fallback" "$index" SystemDefault
    fi
    /usr/bin/plutil -replace AllSpacesAndDisplays -string '$null' "$index"
    /usr/bin/plutil -replace Displays -dictionary "$index"
  ''}
  /usr/bin/plutil -convert binary1 "$index"
  ${settingsScripts}/bin/mv --force --no-target-directory -- "$index" "$store/Index.plist"
''

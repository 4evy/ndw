{ lib }:
{
  inventory = ''
    split("\u0000")[:-1] as $fields
    | [range(0; $fields | length; 3) as $i
       | {name: $fields[$i], kind: $fields[$i + 1], uid: ($fields[$i + 2] | tonumber)}]
  '';
  tasks = ''
    . as $current | ($current + $previous) | group_by([.user, .uid])
    | map(. as $history | $history[0] as $owner
      | ([$current[] | select(.user == $owner.user and .uid == $owner.uid)][0]) as $new
      | ($new // $owner) + {
          source: ($new.source // $empty), current: ($new != null),
          entries: ($new.entries // []),
          previous: [$previous[] | select(.user == $owner.user and .uid == $owner.uid)
                     | .entries[]] | unique_by([.name, .kind])
        }
      | select((.entries + .previous | length) > 0))
  '';
  reconcile = ''
    . as $task | INDEX($existing[]; .name) as $installed
    | INDEX($task.previous[]; .name) as $owned
    | [$task.entries[] as $entry | $installed[$entry.name] as $live
       | select($live != null and ($live.kind == "l" or $live.kind != $entry.kind
           or $live.uid != $task.uid or $owned[$entry.name] == null))
       | $entry.name] as $conflicts
    | if ($conflicts | length) > 0 and ($legacy | not)
      then error("refusing to overwrite unmanaged or replaced applications: " + ($conflicts | join(", ")))
      else . end
    | . + {
        names: ([$task.entries[].name] +
          [$task.previous[] as $old | $installed[$old.name] as $live
           | select($live != null and $live.kind == $old.kind
               and $live.kind != "l" and $live.uid == $task.uid) | $old.name] | unique),
        probes: ([$task.previous[] as $old | $installed[$old.name] as $live
          | select($live.kind == "d" and $live.uid == $task.uid)
          | $task.target + "/" + $old.name] | unique)
      }
  '';
  legacyLink =
    path:
    "[[ -L ${path} && $(readlink -- ${path}) == ${builtins.storeDir}/*-system-applications/Applications ]]";
  readRecords = fields: input: body: ''
    while ${
      lib.strings.concatStringsSep " && " (
        map (name: ''IFS= read -r -d "" ${name}'') (builtins.attrNames fields)
      )
    }; do
      ${body}
    done < <(jq --raw-output0 ${
      lib.strings.escapeShellArg (
        ".[] | ("
        + lib.strings.concatStringsSep ", " (map (value: "(${value})") (builtins.attrValues fields))
        + ")"
      )
    } <<< "${input}")
  '';
}

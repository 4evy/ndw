{ lib, live }:
let
  q = lib.escapeShellArg;
  inherit (import ./plist.nix { inherit lib; }) xml;

  domain =
    key:
    if key.scope == "system" then
      q (if lib.hasPrefix "/" key.domain then key.domain else "/Library/Preferences/${key.domain}")
    else if lib.hasPrefix "~/" key.domain then
      ''"$HOME"/${q (lib.removePrefix "~/" key.domain)}''
    else
      q key.domain;

  defaultsFor =
    verb: key: rest:
    lib.optional key.byHost "-currentHost"
    ++ [
      verb
      (domain key)
    ]
    ++ map q (lib.optional (key.name != null) key.name ++ rest);

  plistType =
    value:
    if lib.isBool value then
      "bool"
    else if lib.isInt value then
      "int"
    else if lib.isFloat value then
      "float"
    else if lib.isString value then
      "string"
    else if lib.isList value then
      "array"
    else if lib.isAttrs value then
      "dict"
    else
      throw "can't store ${builtins.toJSON value} in a preference";

  scalar =
    value:
    if lib.isBool value then
      lib.boolToString value
    else if lib.isFloat value then
      builtins.toJSON value
    else
      toString value;

  typed =
    value:
    if lib.isList value || lib.isAttrs value || lib.isFloat value then
      [ (xml value) ]
    else
      [
        "-${plistType value}"
        (scalar value)
      ];

  plistValues =
    value:
    if lib.isList value then
      lib.concatMap typed value
    else if lib.isAttrs value then
      lib.concatLists (lib.mapAttrsToList (k: v: [ k ] ++ typed v) value)
    else
      [ (scalar value) ];

  defaults = args: "/usr/bin/defaults ${lib.concatStringsSep " " args}";

  # Propagate failures so activation cannot commit a partially applied system
  orReport =
    operation: command:
    "${command} || { printf '%s\\n' ${q "darwin.settings: ${operation.op} failed for ${operation.key.domain}.${toString operation.key.name}"} >&2; exit 1; }";

  step =
    s:
    if s.op == "write" then
      let
        type = if s.key.type != null then s.key.type else plistType s.value;
        # defaults -float rounds to 32 bits, XML preserves double precision
        values =
          if type == "float" then
            [ "<real>${lib.escapeXML (scalar s.value)}</real>" ]
          else
            [ "-${type}" ] ++ plistValues s.value;
      in
      orReport s (defaults (defaultsFor "write" s.key values))

    else if s.op == "delete" then
      "${defaults (defaultsFor "delete" s.key [ ])} 2>/dev/null || true"

    else if s.op == "writeFlags" then
      let
        read = defaults (defaultsFor "read" s.key [ ]);
        write = defaults (defaultsFor "write" s.key [ "-int" ]);
      in
      ''
        current=$(${read} 2>/dev/null || echo ${toString s.absent})
        if [[ $current =~ ^-?[0-9]+$ ]]; then
          # Leading zeroes must not select Bash's octal arithmetic base
          if [[ $current == -* ]]; then
            current=$((-10#''${current#-}))
          else
            current=$((10#$current))
          fi
        else
          current=0
        fi
        ${orReport s "${write} \"$(( (current & ~${toString s.mask}) | ${toString s.bits} ))\""}''

    else if s.op == "mergeDict" then
      if lib.any lib.isAttrs (lib.attrValues s.entries) then
        if s.key.scope != "user" || s.key.byHost || lib.hasPrefix "~/" s.key.domain then
          throw "Nested dictionary updates require a plain user preference domain"
        else
          orReport s (live.mergeDict s.key.domain s.key.name s.entries)
      else
        orReport s (defaults (defaultsFor "write" s.key ([ "-dict-add" ] ++ plistValues s.entries)))

    # defaults can't edit an array in place
    else if s.op == "setMembers" then
      if s.key.byHost || s.key.scope != "user" || lib.hasPrefix "~/" s.key.domain then
        throw "setMembers only supports plain user domains, not ${s.key.domain}"
      else
        orReport s (live.setMembers s.key.domain s.key.name s.members)

    else if s.op == "restore" then
      lib.concatStringsSep "\n" [
        # import only adds and replaces keys
        "${defaults (defaultsFor "delete" s.key [ ])} 2>/dev/null || true"
        (orReport s (
          defaults (
            lib.optional s.key.byHost "-currentHost"
            ++ [
              "import"
              (domain s.key)
              (q s.file)
            ]
          )
        ))
      ]

    else if s.op == "run" then
      s.command

    else
      throw "unknown plan step ${s.op}";

in
{
  /**
    Generate a command exporting a key's whole preference domain to a file

    Ignore the key name. `file` is inserted as shell source so callers can use
    runtime variables. Quote literal paths with `lib.escapeShellArg`

    # Inputs

    `key`
    : Storage key identifying the domain and scope

    `file`
    : Trusted shell expression for the destination

    # Type

    ```
    export :: StorageKey -> String -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.render.export` usage example

    ```nix
    s.render.export (s.user "com.apple.dock" "autohide") "\"$dir\"/dock.plist"
    ```

    :::
  */
  export = key: file: "${defaults (defaultsFor "export" (key // { name = null; }) [ ])} ${file}";

  /**
    Render an operation plan as Bash source without executing it

    Render storage edits and `run` commands in plan order, then unique
    notifications, process restarts, and `afterwards` commands. Deduplicate
    restarts by process name. Any discard request makes that process use SIGKILL

    Write failures exit with status 1. Deletes, notifications, and restarts
    ignore failures. Nested dictionary merges and array membership edits require
    plain user preference domains. Whole-domain restores delete before importing

    The output has no shebang. Run it with Bash and failure handling such as
    `bash -e`, in the appropriate user or root context

    # Inputs

    `plan`
    : List of operation records from `ops`

    # Type

    ```
    script :: Plan -> String
    ```

    # Examples
    :::{.example}
    ## `lib.darwin.settings.render.script` usage example

    ```nix
    s.render.script [ (s.ops.write (s.user "com.apple.dock" "autohide") true) ]
    ```

    :::
  */
  script =
    plan:
    let
      ofOp = op: lib.filter (s: s.op == op) plan;
      restarts = ofOp "restart";
      discarded = process: lib.any (s: s.process == process && s.discard) restarts;
    in
    lib.concatStringsSep "\n" (
      map step (
        lib.filter (
          s:
          !(lib.elem s.op [
            "notify"
            "restart"
            "afterwards"
          ])
        ) plan
      )
      ++ map (name: "/usr/bin/notifyutil -p ${q name} 2>/dev/null || true") (
        lib.unique (map (s: s.name) (ofOp "notify"))
      )
      ++ map (
        process:
        "/usr/bin/killall ${lib.optionalString (discarded process) "-KILL "}${q process} 2>/dev/null || true"
      ) (lib.unique (map (s: s.process) restarts))
      ++ lib.unique (map (s: s.command) (ofOp "afterwards"))
    );
}

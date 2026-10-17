{ lib }:
let
  overlapAgrees =
    left: right:
    lib.all (
      name:
      let
        a = left.${name};
        b = right.${name};
      in
      if lib.isAttrs a && lib.isAttrs b then overlapAgrees a b else a == b
    ) (lib.attrNames (lib.intersectAttrs left right));
  compatible =
    a: b:
    if a.op == "delete" || b.op == "delete" then
      a.op == b.op
    else if a.op == "restore" || b.op == "restore" then
      a.op == b.op && a.file == b.file
    else if a.op == "write" && b.op == "write" then
      a.value == b.value
    else if a.op == "mergeDict" && b.op == "mergeDict" then
      overlapAgrees a.entries b.entries
    else if a.op == "setMembers" && b.op == "setMembers" then
      overlapAgrees a.members b.members
    else if a.op == "writeFlags" && b.op == "writeFlags" then
      builtins.bitAnd (builtins.bitXor a.bits b.bits) (builtins.bitAnd a.mask b.mask) == 0
    else if a.op != "write" && b.op == "write" then
      compatible b a
    else if a.op == "write" && b.op == "writeFlags" then
      lib.isInt a.value && builtins.bitAnd a.value b.mask == b.bits
    else if a.op == "write" && b.op == "mergeDict" then
      lib.isAttrs a.value && lib.recursiveUpdate a.value b.entries == a.value
    else if a.op == "write" && b.op == "setMembers" then
      lib.isList a.value
      && lib.all (item: lib.elem item a.value == b.members.${item}) (lib.attrNames b.members)
    else
      false;
  identity =
    key:
    builtins.toJSON {
      inherit (key) scope byHost name;
      domain =
        if
          lib.elem key.domain [
            "NSGlobalDomain"
            ".GlobalPreferences"
            "-g"
          ]
        then
          "-g"
        else
          key.domain;
    };
in
plan:
lib.concatLists (
  lib.mapAttrsToList
    (
      _: steps:
      let
        pairs = lib.concatMap (
          a: map (b: { inherit a b; }) (lib.filter (b: a.setting < b.setting && !(compatible a b)) steps)
        ) steps;
      in
      map (pair: {
        assertion = false;
        message = "darwin.settings: ${pair.a.setting} and ${pair.b.setting} configure the same preference differently (${pair.a.key.domain}.${toString pair.a.key.name})";
      }) pairs
    )
    (
      lib.groupBy (step: identity step.key) (
        lib.filter (
          step:
          step ? key
          && lib.elem step.op [
            "write"
            "delete"
            "mergeDict"
            "setMembers"
            "writeFlags"
            "restore"
          ]
        ) plan
      )
    )
)

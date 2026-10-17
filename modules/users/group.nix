{ name, lib, ... }:
let
  inherit (lib.darwin.options) mkDefaultOption;
in

{
  options =
    let
      inherit (lib) mkOption types;
    in
    {
      name = mkDefaultOption types.str name ''
        The group's name. If undefined, the name of the attribute set
        will be used.
      '';

      gid = mkOption {
        type = types.ints.unsigned;
        description = "The group's GID.";
      };

      members = mkDefaultOption (types.listOf types.str) [ ] "The group's members.";

      description = mkDefaultOption types.str "" "The group's description.";
    };
}

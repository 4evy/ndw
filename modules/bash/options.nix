{
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
in
{
  options.programs.bash = {
    enable = lib.options.mkEnableOption "Bash configuration";
    package = lib.options.mkPackageOption pkgs "bash" {
      default = "bashInteractive";
      nullable = true;
    };
    completion.enable = mkDefaultOption lib.types.bool true "Enable Bash completion.";
    history = {
      size = mkDefaultOption (lib.types.nullOr lib.types.int) 10000 "History lines kept in memory.";
      file.path = lib.darwin.options.mkNullableOption lib.types.str "History file path. Shell variables are expanded.";
      file.size = mkDefaultOption (lib.types.nullOr lib.types.int) 100000 "History lines saved to disk.";
      control = mkDefaultOption (lib.types.listOf (
        lib.types.enum [
          "erasedups"
          "ignoredups"
          "ignorespace"
          "ignoreboth"
        ]
      )) [ ] "Bash history control flags.";
      ignore = mkDefaultOption (lib.types.listOf lib.types.str) [ ] "Commands omitted from history.";
    };
    shell.options = mkDefaultOption (lib.types.listOf lib.types.str) [
      "histappend"
      "extglob"
      "globstar"
      "checkjobs"
    ] "Shell options. Prefix an option with - to unset it.";
    shell.aliases = mkDefaultOption (lib.types.attrsOf lib.types.str) { } "Bash aliases.";
    session.variables = lib.options.mkOption {
      inherit (options.environment.variables) type;
      default = { };
      description = ''
        Bash session variables. Null entries are omitted. XDG_STATE_HOME is
        set before expanding profile paths in the shared environment.
      '';
    };
    profile.extra = mkDefaultOption lib.types.lines "" "Extra commands for login shells.";
    init.extra = mkDefaultOption lib.types.lines "" "Extra commands for interactive shells.";
    bashrc.extra =
      mkDefaultOption lib.types.lines ""
        "Commands run before the interactive-shell guard.";
    logout.extra =
      mkDefaultOption lib.types.lines ""
        "Commands run by the packaged Bash at login-shell logout.";
  };
}

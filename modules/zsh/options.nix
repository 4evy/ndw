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
  options.programs.zsh = {
    enable = lib.options.mkEnableOption "Zsh configuration";
    package = lib.options.mkPackageOption pkgs "zsh" { nullable = true; };
    autocd = lib.darwin.options.mkNullableOption lib.types.bool "Enter directories by typing their path.";
    cdpath = mkDefaultOption (lib.types.listOf lib.types.str) [ ] "Directories searched by cd.";
    dot.dir = lib.darwin.options.mkNullableOption lib.types.str "Directory searched for users' own Zsh dotfiles. Shell variables are expanded.";
    shell.aliases = mkDefaultOption (lib.types.attrsOf lib.types.str) { } "Zsh aliases.";
    shell.global.aliases =
      mkDefaultOption (lib.types.attrsOf lib.types.str) { }
        "Aliases expanded anywhere on a command line.";
    dir.hashes =
      mkDefaultOption (lib.types.attrsOf lib.types.str) { }
        "Named directories. Shell variables are expanded.";
    completion = {
      enable = mkDefaultOption lib.types.bool true "Enable Zsh completion.";
      init =
        mkDefaultOption lib.types.lines "autoload -U compinit && compinit"
          "Completion initialization commands.";
    };
    default.keymap = lib.darwin.options.mkNullableOption (lib.types.enum [
      "emacs"
      "viins"
      "vicmd"
    ]) "Default keymap.";
    session.variables = lib.options.mkOption {
      inherit (options.environment.variables) type;
      default = { };
      description = ''
        Zsh session variables. Null entries are omitted. XDG_STATE_HOME is
        set before expanding profile paths in the shared environment.
      '';
    };
    local.variables =
      mkDefaultOption (lib.types.attrsOf lib.types.anything) { }
        "Local scalars, arrays, and associative arrays.";
    set.options =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ]
        "Zsh options. Prefix with NO_ to unset.";
    site.functions =
      mkDefaultOption (lib.types.attrsOf lib.types.lines) { }
        "Functions added to fpath and marked for autoloading.";
    init.content = mkDefaultOption lib.types.lines "" ''
      Interactive initialization ordered with lib.modules.mkOrder. Use 500
      for early setup, 550 before completion, 1000 for normal configuration,
      and 1500 for commands after plugins and highlighting.
    '';
    env.extra = mkDefaultOption lib.types.lines "" "Extra commands for all Zsh shells.";
    profile.extra = mkDefaultOption lib.types.lines "" "Extra commands for login-shell setup.";
    login.extra = mkDefaultOption lib.types.lines "" "Extra commands after login-shell setup.";
    logout.extra = mkDefaultOption lib.types.lines "" "Extra commands when login shells exit.";
    zprof.enable = lib.options.mkEnableOption "Zsh initialization profiling";
  };
}

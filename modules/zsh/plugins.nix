{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf mkOrder;
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.programs.zsh;
  shell = lib.darwin.shell;
  variables =
    values: lib.strings.toShellVars (lib.attrsets.filterAttrs (_: value: value != null) values);
  strings = lib.types.listOf lib.types.str;
  values = lib.types.attrsOf lib.types.str;
  plugin = lib.types.submodule (
    { config, ... }: {
      options = {
        name = lib.options.mkOption {
          type = lib.types.str;
          description = "Plugin name.";
        };
        src = lib.options.mkOption {
          type = lib.types.path;
          description = "Plugin source directory.";
        };
        file =
          mkDefaultOption lib.types.str "${config.name}.plugin.zsh"
            "Script to source relative to src.";
        functions = mkDefaultOption strings [ ] "Additional function directories relative to src.";
      };
    }
  );
  paths = lib.lists.concatMap (
    item: [ (toString item.src) ] ++ map (path: "${item.src}/${path}") item.functions
  ) cfg.plugins;
  highlighting = cfg.syntax.highlighting;
  fast = cfg.fast.syntax.highlighting;
  suggestions = cfg.autosuggestion;
  omz = cfg.oh.my.zsh;
  abbreviation = cfg.zsh.abbr;
  pairs =
    values:
    lib.lists.concatLists (
      lib.attrsets.mapAttrsToList (name: value: [
        name
        value
      ]) values
    );
in
{
  imports = [ ./prezto.nix ];
  options.programs.zsh = {
    plugins = mkDefaultOption (lib.types.listOf plugin) [ ] "Plugins to source in interactive shells.";
    syntax.highlighting = {
      enable = lib.options.mkEnableOption "Zsh syntax highlighting";
      package = lib.options.mkPackageOption pkgs "zsh-syntax-highlighting" { };
      highlighters = mkDefaultOption strings [ ] "Highlighters to enable. Main is included by default.";
      styles = mkDefaultOption values { } "Syntax highlighting styles.";
      patterns = mkDefaultOption values { } "Syntax highlighting patterns.";
    };
    fast.syntax.highlighting = {
      enable = lib.options.mkEnableOption "fast Zsh syntax highlighting";
      package = lib.options.mkPackageOption pkgs "zsh-fast-syntax-highlighting" { };
      theme = lib.darwin.options.mkNullableOption lib.types.str "Theme selected with fast-theme.";
      settings = mkDefaultOption values { } "Additional FAST_HIGHLIGHT settings.";
    };
    autosuggestion = {
      enable = lib.options.mkEnableOption "Zsh autosuggestions";
      highlight = lib.darwin.options.mkNullableOption lib.types.str "Autosuggestion highlighting style.";
      strategy = mkDefaultOption (lib.types.listOf (
        lib.types.enum [
          "history"
          "completion"
          "match_prev_cmd"
        ]
      )) [ "history" ] "Strategies tried when generating suggestions.";
    };
    oh.my.zsh = {
      enable = lib.options.mkEnableOption "Oh My Zsh";
      package = lib.options.mkPackageOption pkgs "oh-my-zsh" { };
      plugins = mkDefaultOption strings [ ] "Oh My Zsh plugins.";
      custom = mkDefaultOption lib.types.str "" "Custom Oh My Zsh directory.";
      theme = mkDefaultOption lib.types.str "" "Oh My Zsh theme.";
      extra.config = mkDefaultOption lib.types.lines "" "Settings loaded before Oh My Zsh.";
    };
    zsh.abbr = {
      enable = lib.options.mkEnableOption "Zsh abbreviations";
      package = lib.options.mkPackageOption pkgs "zsh-abbr" { };
      abbreviations = mkDefaultOption values { } "Command abbreviations.";
      global.abbreviations = mkDefaultOption values { } "Abbreviations expanded anywhere in a command.";
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(highlighting.enable && fast.enable);
        message = "Enable only one Zsh syntax highlighter";
      }
      {
        assertion = !(omz.enable && cfg.prezto.enable);
        message = "Enable only one of Oh My Zsh and Prezto";
      }
    ];
    programs.zsh.syntax.highlighting.highlighters = mkIf highlighting.enable [ "main" ];
    programs.zsh.init.content = lib.modules.mkMerge [
      (mkIf (cfg.plugins != [ ]) (
        mkOrder 560 ''
          path+=(${
            lib.strings.concatMapStringsSep " " lib.strings.escapeShellArg (
              map (item: toString item.src) cfg.plugins
            )
          })
          fpath+=(${lib.strings.escapeShellArgs paths})
        ''
      ))
      (mkIf suggestions.enable (
        mkOrder 700 ''
          source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
          ${variables {
            ZSH_AUTOSUGGEST_STRATEGY = if suggestions.strategy == [ ] then null else suggestions.strategy;
            ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE = suggestions.highlight;
          }}
        ''
      ))
      (mkIf omz.enable (
        mkOrder 800 ''
          ${lib.strings.toShellVars { ZSH = "${omz.package}/share/oh-my-zsh"; }}
          ZSH_CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
          ${pkgs.coreutils}/bin/mkdir --parents -- "$ZSH_CACHE_DIR"
          ${omz.extra.config}
          ${variables {
            plugins = omz.plugins;
            ZSH_THEME = if omz.theme == "" then null else omz.theme;
          }}
          ${lib.strings.optionalString (omz.custom != "") "ZSH_CUSTOM=${shell.doubleQuote omz.custom}"}
          source "$ZSH/oh-my-zsh.sh"
        ''
      ))
      (mkOrder 900 (
        shell.commandLines (
          map (item: [
            "source"
            "${item.src}/${item.file}"
          ]) cfg.plugins
        )
      ))
      (mkIf abbreviation.enable (
        mkOrder 920 ''
          source ${abbreviation.package}/share/zsh/zsh-abbr/zsh-abbr.plugin.zsh
          ${lib.strings.concatMapAttrsStringSep "\n" (
            name: value:
            lib.strings.escapeShellArgs [
              "abbr"
              "${name}=${value}"
            ]
          ) abbreviation.abbreviations}
          ${lib.strings.concatMapAttrsStringSep "\n" (
            name: value:
            lib.strings.escapeShellArgs [
              "abbr"
              "-g"
              "${name}=${value}"
            ]
          ) abbreviation.global.abbreviations}
        ''
      ))
      (mkIf highlighting.enable (
        mkOrder 1200 ''
          source ${highlighting.package}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
          ${variables {
            ZSH_HIGHLIGHT_HIGHLIGHTERS = highlighting.highlighters;
          }}
          ${lib.strings.concatMapAttrsStringSep "\n" (
            name: value:
            "ZSH_HIGHLIGHT_STYLES[${lib.strings.escapeShellArg name}]=${lib.strings.escapeShellArg value}"
          ) highlighting.styles}
          ZSH_HIGHLIGHT_PATTERNS+=(${lib.strings.escapeShellArgs (pairs highlighting.patterns)})
        ''
      ))
      (mkIf fast.enable (
        mkOrder 1200 ''
          source ${fast.package}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
          ${lib.strings.optionalString (fast.theme != null) (
            lib.strings.escapeShellArgs [
              "fast-theme"
              "-q"
              fast.theme
            ]
          )}
          FAST_HIGHLIGHT+=(${lib.strings.escapeShellArgs (pairs fast.settings)})
        ''
      ))
    ];
  };
}

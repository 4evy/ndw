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
  history = {
    APPEND_HISTORY = cfg.history.append;
    HIST_IGNORE_DUPS = cfg.history.ignore.dups;
    HIST_IGNORE_ALL_DUPS = cfg.history.ignore.all.dups;
    HIST_SAVE_NO_DUPS = cfg.history.duplicates.save.ignore;
    HIST_FIND_NO_DUPS = cfg.history.duplicates.find.ignore;
    HIST_IGNORE_SPACE = cfg.history.ignore.space;
    HIST_EXPIRE_DUPS_FIRST = cfg.history.expire.duplicates.first;
    SHARE_HISTORY = cfg.history.share;
    EXTENDED_HISTORY = cfg.history.extended;
  }
  // lib.attrsets.optionalAttrs (cfg.autocd != null) { AUTO_CD = cfg.autocd; };
in
{
  options.programs.zsh.history = {
    append = mkDefaultOption lib.types.bool false "Append history on shell exit.";
    size = mkDefaultOption lib.types.int 10000 "History entries kept in memory.";
    save = mkDefaultOption lib.types.int cfg.history.size "History entries saved to disk.";
    path =
      mkDefaultOption lib.types.str "$HOME/.zsh_history"
        "History file path. Shell variables are expanded.";
    ignore.patterns =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ]
        "Patterns excluded from history.";
    ignore.dups = mkDefaultOption lib.types.bool true "Omit immediately repeated commands.";
    ignore.all.dups = mkDefaultOption lib.types.bool false "Remove older duplicate commands.";
    duplicates.save.ignore =
      mkDefaultOption lib.types.bool false
        "Omit duplicate commands when saving history.";
    duplicates.find.ignore =
      mkDefaultOption lib.types.bool false
        "Hide duplicates during history searches.";
    ignore.space = mkDefaultOption lib.types.bool true "Omit commands beginning with a space.";
    expire.duplicates.first = mkDefaultOption lib.types.bool false "Expire duplicate commands first.";
    extended = mkDefaultOption lib.types.bool false "Save timestamps with history entries.";
    share = mkDefaultOption lib.types.bool true "Share history between Zsh sessions.";
  };
  options.programs.zsh.history.substring.search = {
    enable = lib.options.mkEnableOption "Zsh history substring search";
    up.keys = mkDefaultOption (lib.types.either lib.types.str (lib.types.listOf lib.types.str)) [
      "^[[A"
    ] "Keys that search backward.";
    down.keys = mkDefaultOption (lib.types.either lib.types.str (lib.types.listOf lib.types.str)) [
      "^[[B"
    ] "Keys that search forward.";
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.strings.hasPrefix "/" cfg.history.path || lib.strings.hasInfix "$" cfg.history.path;
        message = "programs.zsh.history.path must be absolute or contain a shell variable";
      }
    ];
    programs.zsh.set.options = [
      "HIST_FCNTL_LOCK"
    ]
    ++ lib.attrsets.mapAttrsToList (name: enabled: if enabled then name else "NO_${name}") history;
    programs.zsh.init.content = lib.modules.mkMerge [
      (mkOrder 910 ''
        ${lib.strings.toShellVars (
          {
            HISTSIZE = cfg.history.size;
            SAVEHIST = cfg.history.save;
          }
          // lib.attrsets.optionalAttrs (cfg.history.ignore.patterns != [ ]) {
            HISTORY_IGNORE = "(${lib.strings.concatStringsSep "|" cfg.history.ignore.patterns})";
          }
        )}
        HISTFILE=${shell.doubleQuote cfg.history.path}
        ${pkgs.coreutils}/bin/mkdir --parents -- "$(${pkgs.coreutils}/bin/dirname -- "$HISTFILE")"
      '')
      (mkIf cfg.history.substring.search.enable (
        mkOrder 1250 ''
          source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
          ${shell.commandLines (
            map (key: [
              "bindkey"
              key
              "history-substring-search-up"
            ]) (lib.lists.toList cfg.history.substring.search.up.keys)
          )}
          ${shell.commandLines (
            map (key: [
              "bindkey"
              key
              "history-substring-search-down"
            ]) (lib.lists.toList cfg.history.substring.search.down.keys)
          )}
        ''
      ))
    ];
  };
}

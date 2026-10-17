# Interface and initialization adapted from Home Manager
# https://github.com/nix-community/home-manager/commit/640725978b99076e18e069f6e7d2959124584f8f
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.bash;
  shell = lib.darwin.shell;
  settings = {
    HISTSIZE = cfg.history.size;
    HISTFILESIZE = cfg.history.file.size;
    HISTCONTROL =
      if cfg.history.control == [ ] then null else lib.strings.concatStringsSep ":" cfg.history.control;
    HISTIGNORE =
      if cfg.history.ignore == [ ] then null else lib.strings.concatStringsSep ":" cfg.history.ignore;
  };
  options = (lib.strings.concatStringsSep "\n") (
    map (
      value:
      lib.strings.escapeShellArgs [
        "shopt"
        (if lib.strings.hasPrefix "-" value then "-u" else "-s")
        (lib.strings.removePrefix "-" value)
      ]
      + " 2>/dev/null || :"
    ) cfg.shell.options
  );
in
{
  imports = [ ./options.nix ];
  config = lib.modules.mkIf cfg.enable {
    programs.bash.shell.aliases = lib.attrsets.mapAttrs (
      _: lib.modules.mkDefault
    ) config.environment.shell.aliases;
    environment.system.packages =
      lib.lists.optional cfg.completion.enable pkgs.bash-completion
      ++ lib.lists.optional (cfg.package != null) cfg.package;
    programs.bash.init.extra = lib.modules.mkIf cfg.completion.enable (
      lib.modules.mkOrder 100 ''
        if (( BASH_VERSINFO[0] >= 4 )) && [[ -z ''${BASH_COMPLETION_VERSINFO:-} ]]; then
          source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
          ${lib.strings.concatMapStringsSep "\n" (profile: ''
            for completion in ${shell.doubleQuote "${profile}/etc/bash_completion.d/"}*; do
              if [[ -r $completion ]]; then source "$completion"; fi
            done
          '') config.environment.profiles}
          unset completion
        fi
      ''
    );
    environment.files.bashrc.known.hashes = (import ./hashes.nix).bashrc;
    environment.files.bashrc.known.macOS = true;
    system.activation.checks = ''
      if /usr/bin/grep -q 'etc/profile.d/nix-daemon.sh' /etc/profile; then
        printf >&2 'error: remove the nix-daemon.sh snippet from /etc/profile before managing Bash, it overrides the configured session\n'
        exit 2
      fi
    '';
    environment.files.bashrc.text = ''
      if [[ -n ''${DARWIN_BASHRC:-} ]]; then return; fi
      DARWIN_BASHRC=1
      # Apple's terminal hooks save session history and require an interactive shell
      if [[ $- == *i* && -r /etc/bashrc_''${TERM_PROGRAM:-} ]]; then
        source "/etc/bashrc_$TERM_PROGRAM"
      fi
      if [[ -z ''${DARWIN_SESSION:-} ]]${
        lib.strings.optionalString (
          cfg.session.variables.XDG_STATE_HOME or null != null
        ) " || [[ \${XDG_STATE_HOME:-} != ${shell.doubleQuote cfg.session.variables.XDG_STATE_HOME} ]]"
      }; then
        source ${config.system.build.sessionFor cfg.session.variables}
        export DARWIN_SESSION=1
      else
        ${shell.exportAll cfg.session.variables}
        :
      fi
      ${lib.strings.optionalString (cfg.profile.extra != "") ''
        if shopt -q login_shell; then
          ${cfg.profile.extra}
          :
        fi
      ''}
      ${cfg.bashrc.extra}
      # Skipping interactive setup must not fail a login shell using errexit
      [[ $- == *i* ]] || return 0
      ${lib.strings.toShellVars (lib.attrsets.filterAttrs (_: value: value != null) settings)}
      ${lib.strings.optionalString (
        cfg.history.file.path != null
      ) "HISTFILE=${shell.doubleQuote cfg.history.file.path}"}
      ${lib.strings.optionalString (
        cfg.history.file.path != null
      ) ''${pkgs.coreutils}/bin/mkdir --parents -- "$(${pkgs.coreutils}/bin/dirname -- "$HISTFILE")"''}
      ${options}
      ${shell.mkAliases [ ] cfg.shell.aliases}
      ${cfg.init.extra}
    '';
    environment.files.bash_logout = lib.modules.mkIf (cfg.logout.extra != "") {
      text = cfg.logout.extra;
    };
  };
}

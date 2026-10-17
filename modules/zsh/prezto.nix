# Interface adapted from Home Manager
# https://github.com/nix-community/home-manager/commit/640725978b99076e18e069f6e7d2959124584f8f
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption mkNullableOption;
  cfg = config.programs.zsh.prezto;
  toggle = description: mkNullableOption lib.types.bool description // { example = true; };
in
{
  options.programs.zsh.prezto = {
    enable = lib.options.mkEnableOption "prezto";

    package = lib.options.mkPackageOption pkgs "prezto" { default = "zsh-prezto"; };

    case.sensitive = lib.options.mkOption {
      type = lib.types.nullOr lib.types.bool;
      # See <https://github.com/nix-community/home-manager/issues/2255>
      default = true;
      example = true;
      description = "Set case-sensitivity for completion, history lookup, etc.";
    };

    color =
      mkDefaultOption (lib.types.nullOr lib.types.bool) true ''
        Color output (automatically set to `false` on dumb terminals).
      ''
      // {
        example = false;
      };

    pmodule.dirs =
      mkDefaultOption (lib.types.listOf lib.types.path) [ ]
        "Add additional directories to load prezto modules from.";

    extra.config = mkDefaultOption lib.types.lines "" ''
      Additional commands before Prezto initialization.
    '';

    extra.modules =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ] ''
        Set the Zsh modules to load ({manpage}`zshmodules(1)`).
      ''
      // {
        example = [
          "attr"
          "stat"
        ];
      };

    extra.functions =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ] ''
        Set the Zsh functions to load ({manpage}`zshcontrib(1)`).
      ''
      // {
        example = [
          "zargs"
          "zmv"
        ];
      };

    pmodules = mkDefaultOption (lib.types.listOf lib.types.str) [
      "environment"
      "terminal"
      "editor"
      "history"
      "directory"
      "spectrum"
      "utility"
      "completion"
      "prompt"
    ] "Set the Prezto modules to load (browse modules). The order matters.";

    autosuggestions.color = mkNullableOption lib.types.str "Set the query found color." // {
      example = "fg=blue";
    };

    completions.ignored.hosts =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ] ''
        Set the entries to ignore in static {file}`/etc/hosts` for
        host completion.
      ''
      // {
        example = [
          "0.0.0.0"
          "127.0.0.1"
        ];
      };

    editor = {
      keymap =
        mkDefaultOption
          (lib.types.nullOr (
            lib.types.enum [
              "emacs"
              "vi"
            ]
          ))
          "emacs"
          ''
            Set the key mapping style to `emacs` or `vi`.
          ''
        // {
          example = "vi";
        };

      dot.expansion = toggle ''
        Automatically convert `....` to `../..`
      '';

      prompt.context = toggle "Allow the Zsh prompt context to be shown.";
    };

    git.submodule.ignore =
      mkNullableOption
        (lib.types.enum [
          "dirty"
          "untracked"
          "all"
          "none"
        ])
        ''
          Ignore submodules when they are `dirty`, `untracked`, `all`,
          or `none`.
        ''
      // {
        example = "all";
      };

    gnu.utility.prefix =
      mkNullableOption lib.types.str "Set the command prefix on non-GNU systems."
      // {
        example = "g";
      };

    history.substring = {
      found.color = mkNullableOption lib.types.str "Set the query found color." // {
        example = "fg=blue";
      };

      not.found.color = mkNullableOption lib.types.str "Set the query not found color." // {
        example = "fg=red";
      };

      globbing.flags = mkNullableOption lib.types.str "Set the search globbing flags.";
    };

    mac.os.dash.keyword =
      mkNullableOption lib.types.str ''
        Set the keyword used by {command}`mand` to open man pages
        in Dash.app.
      ''
      // {
        example = "manpages";
      };

    prompt = {
      theme =
        mkDefaultOption (lib.types.nullOr lib.types.str) "sorin" ''
          Set the prompt theme to load. Setting it to `random`
          loads a random theme. Automatically set to `off` on dumb
          terminals.
        ''
        // {
          example = "pure";
        };

      pwd.length =
        mkNullableOption
          (lib.types.enum [
            "short"
            "long"
            "full"
          ])
          ''
            Set the working directory prompt display length. By
            default, it is set to `short`. Set it to `long` (without `~`
            expansion) for longer or `full` (with `~` expansion) for
            even longer prompt display.
          ''
        // {
          example = "short";
        };

      show.return.val = toggle ''
        Set the prompt to display the return code along with an
        indicator for non-zero return codes. This is not supported by all prompts.
      '';
    };

    python = {
      virtualenv.auto.switch = toggle "Auto switch to Python virtualenv on directory change.";

      virtualenv.initialize = toggle "Automatically initialize virtualenvwrapper if pre-requisites are met.";
    };

    ruby.chruby.auto.switch = toggle "Auto switch the Ruby version on directory change.";

    screen = {
      auto.start.local = toggle "Auto start a session when Zsh is launched in a local terminal.";

      auto.start.remote = toggle "Auto start a session when Zsh is launched in a SSH connection.";
    };

    ssh.identities =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ]
        "Set the SSH identities to load into the agent."
      // {
        example = [
          "id_rsa"
          "id_rsa2"
          "id_github"
        ];
      };

    syntax.highlighting = {
      highlighters =
        mkDefaultOption (lib.types.listOf lib.types.str) [ ] ''
          Set syntax highlighters. By default, only the main
          highlighter is enabled.
        ''
        // {
          example = [
            "main"
            "brackets"
            "pattern"
            "line"
            "cursor"
            "root"
          ];
        };

      styles =
        mkDefaultOption (lib.types.attrsOf lib.types.str) { } "Set syntax highlighting styles."
        // {
          example = {
            builtin = "bg=blue";
            command = "bg=blue";
            function = "bg=blue";
          };
        };

      pattern = mkDefaultOption (lib.types.attrsOf lib.types.str) { } "Set syntax pattern styles." // {
        example = {
          "rm*-rf*" = "fg=white,bold,bg=red";
        };
      };
    };

    terminal = {
      auto.title = toggle "Auto set the tab and window titles.";

      window.title.format = mkNullableOption lib.types.str "Set the window title format." // {
        example = "%n@%m: %s";
      };

      tab.title.format = mkNullableOption lib.types.str "Set the tab title format." // {
        example = "%m: %s";
      };

      multiplexer.title.format = mkNullableOption lib.types.str "Set the multiplexer title format." // {
        example = "%s";
      };
    };

    tmux = {
      auto.start.local = toggle "Auto start a session when Zsh is launched in a local terminal.";

      auto.start.remote = toggle "Auto start a session when Zsh is launched in a SSH connection.";

      iterm.integration = toggle "Integrate with iTerm2.";

      default.session.name = mkNullableOption lib.types.str "Set the default session name." // {
        example = "YOUR DEFAULT SESSION NAME";
      };
    };

    utility.safe.ops = toggle ''
      Enabled safe options. This aliases {command}`cp`,
      {command}`ln`, {command}`mv` and {command}`rm` so that they
      prompt before deleting or overwriting files. Set to `no` to
      disable this safer behavior.
    '';
  };
  config = lib.modules.mkIf (config.programs.zsh.enable && cfg.enable) {
    programs.zsh = {
      profile.extra = lib.modules.mkBefore "source ${cfg.package}/share/zsh-prezto/runcoms/zprofile";
      login.extra = lib.modules.mkBefore "source ${cfg.package}/share/zsh-prezto/runcoms/zlogin";
      logout.extra = lib.modules.mkBefore "source ${cfg.package}/share/zsh-prezto/runcoms/zlogout";
      env.extra = lib.modules.mkAfter "source ${cfg.package}/share/zsh-prezto/runcoms/zshenv";
      init.content = lib.modules.mkOrder 850 (
        (lib.strings.concatStringsSep "\n") [
          (lib.darwin.zsh.mkZstyles {
            ":prezto:*:*" = {
              inherit (cfg) color;
              case-sensitive = cfg.case.sensitive;
            };
            ":prezto:load" = {
              pmodule-dirs = cfg.pmodule.dirs;
              zmodule = cfg.extra.modules;
              zfunction = cfg.extra.functions;
              pmodule = cfg.pmodules;
            };
            ":prezto:module:autosuggestions:color".found = cfg.autosuggestions.color;
            ":prezto:module:completion:*:hosts".etc-host-ignores = cfg.completions.ignored.hosts;
            ":prezto:module:editor" = {
              key-bindings = cfg.editor.keymap;
              dot-expansion = cfg.editor.dot.expansion;
              ps-context = cfg.editor.prompt.context;
            };
            ":prezto:module:git:status:ignore".submodules = cfg.git.submodule.ignore;
            ":prezto:module:gnu-utility".prefix = cfg.gnu.utility.prefix;
            ":prezto:module:history-substring-search:color" = {
              found = cfg.history.substring.found.color;
              not-found = cfg.history.substring.not.found.color;
              globbing-flags = cfg.history.substring.globbing.flags;
            };
            ":prezto:module:osx:man".dash-keyword = cfg.mac.os.dash.keyword;
            ":prezto:module:prompt" = {
              theme = cfg.prompt.theme;
              pwd-length = cfg.prompt.pwd.length;
              show-return-val = cfg.prompt.show.return.val;
            };
            ":prezto:module:python:virtualenv" = {
              auto-switch = cfg.python.virtualenv.auto.switch;
              initialize = cfg.python.virtualenv.initialize;
            };
            ":prezto:module:ruby:chruby".auto-switch = cfg.ruby.chruby.auto.switch;
            ":prezto:module:screen:auto-start" = {
              local = cfg.screen.auto.start.local;
              remote = cfg.screen.auto.start.remote;
            };
            ":prezto:module:ssh:load".identities = cfg.ssh.identities;
            ":prezto:module:syntax-highlighting" = {
              inherit (cfg.syntax.highlighting) highlighters styles pattern;
            };
            ":prezto:module:terminal".auto-title = cfg.terminal.auto.title;
            ":prezto:module:terminal:window-title".format = cfg.terminal.window.title.format;
            ":prezto:module:terminal:tab-title".format = cfg.terminal.tab.title.format;
            ":prezto:module:terminal:multiplexer-title".format = cfg.terminal.multiplexer.title.format;
            ":prezto:module:tmux:auto-start" = {
              local = cfg.tmux.auto.start.local;
              remote = cfg.tmux.auto.start.remote;
            };
            ":prezto:module:tmux:iterm".integrate = cfg.tmux.iterm.integration;
            ":prezto:module:tmux:session".name = cfg.tmux.default.session.name;
            ":prezto:module:utility".safe-ops = cfg.utility.safe.ops;
          })
          cfg.extra.config
          "source ${cfg.package}/share/zsh-prezto/init.zsh"
        ]
      );
    };
  };
}

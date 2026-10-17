# Interface and initialization adapted from Home Manager
# https://github.com/nix-community/home-manager/commit/640725978b99076e18e069f6e7d2959124584f8f
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf mkOrder;
  shell = lib.darwin.shell;
  cfg = config.programs.zsh;
  keymaps = {
    emacs = "bindkey -e";
    viins = "bindkey -v";
    vicmd = "bindkey -a";
  };
  functions = pkgs.linkFarm "functions" (
    lib.attrsets.mapAttrsToList (name: text: {
      inherit name;
      path = pkgs.writeText "function" text;
    }) cfg.site.functions
  );
  paths = lib.lists.concatMap (
    profile:
    map (suffix: "${profile}${suffix}") [
      "/share/zsh/site-functions"
      "/share/zsh/$ZSH_VERSION/functions"
      "/share/zsh/vendor-completions"
    ]
  ) config.environment.profiles;
in
{
  imports = [
    ./options.nix
    ./history.nix
    ./plugins.nix
  ];
  config = mkIf cfg.enable {
    programs.zsh.shell.aliases = lib.attrsets.mapAttrs (
      _: lib.modules.mkDefault
    ) config.environment.shell.aliases;
    programs.zsh.session.variables.ZDOTDIR = mkIf (cfg.dot.dir != null) (
      lib.modules.mkDefault cfg.dot.dir
    );
    environment.system.packages =
      lib.lists.optional cfg.completion.enable pkgs.nix-zsh-completions
      ++ lib.lists.optional (cfg.package != null) cfg.package;
    assertions = lib.attrsets.mapAttrsToList (name: _: {
      assertion = lib.darwin.paths.isFileName name;
      message = "Zsh function names must not contain slashes: ${name}";
    }) cfg.site.functions;
    programs.zsh.init.content = lib.modules.mkMerge [
      (mkIf cfg.zprof.enable (mkOrder 400 "zmodload zsh/zprof"))
      (mkOrder 510 ''
        typeset -U path cdpath fpath manpath
        ${lib.strings.optionalString (cfg.cdpath != [ ])
          "cdpath+=(${lib.strings.concatMapStringsSep " " shell.doubleQuote cfg.cdpath})"
        }
      '')
      (mkOrder 520 ''
        fpath=(${lib.strings.concatMapStringsSep " " shell.doubleQuote paths} $fpath)
        ${lib.strings.optionalString (
          cfg.package != null
        ) "HELPDIR=${shell.doubleQuote "${cfg.package}/share/zsh/$ZSH_VERSION/help"}"}
      '')
      (mkIf (cfg.default.keymap != null) (mkOrder 530 keymaps.${cfg.default.keymap}))
      (mkOrder 540 (lib.strings.toShellVars cfg.local.variables))
      (mkIf (cfg.completion.enable && !cfg.oh.my.zsh.enable && !cfg.prezto.enable) (
        mkOrder 570 cfg.completion.init
      ))
      (mkIf (cfg.site.functions != { }) (
        mkOrder 560 ''
          fpath=(${functions} $fpath)
          ${lib.strings.escapeShellArgs (
            [
              "autoload"
              "-Uz"
              "--"
            ]
            ++ builtins.attrNames cfg.site.functions
          )}
        ''
      ))
      (mkIf (cfg.set.options != [ ]) (
        mkOrder 950 (lib.strings.escapeShellArgs ([ "setopt" ] ++ cfg.set.options))
      ))
      (mkOrder 1100 (
        lib.strings.concatStringsSep "\n" (
          lib.lists.filter (text: text != "") [
            (shell.mkAliases [ ] cfg.shell.aliases)
            (shell.mkAliases [ "-g" ] cfg.shell.global.aliases)
          ]
        )
      ))
      (mkOrder 1150 (
        lib.strings.concatMapAttrsStringSep "\n" (
          name: value: "hash -d ${lib.strings.escapeShellArg name}=${shell.doubleQuote value}"
        ) cfg.dir.hashes
      ))
      (mkIf cfg.zprof.enable (mkOrder 1450 "zprof"))
    ];
    environment.files = lib.modules.mkMerge [
      (lib.attrsets.mapAttrs (_: hashes: { known.hashes = hashes; }) (import ./hashes.nix))
      {
        zprofile.known.macOS = true;
        zshrc.known.macOS = true;
        zshenv.text = ''
          if [[ -o rcs ]]; then
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
            ${cfg.env.extra}
          fi
        '';
        zprofile.text = cfg.profile.extra;
        zshrc.text = cfg.init.content;
        zlogin = mkIf (cfg.login.extra != "") { text = cfg.login.extra; };
        zlogout = mkIf (cfg.logout.extra != "") {
          text = cfg.logout.extra;
        };
      }
    ];
  };
}

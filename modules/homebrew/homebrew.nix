{
  config,
  lib,
  pkgs,
  ...
}:
let
  shell = lib.darwin.shell;
  cfg = config.homebrew;
  activation = cfg.on.activation;
  cleanup = activation.cleanup;
  command = lib.strings.escapeShellArgs;
  inherit (lib.darwin.shell) failIf;
  rubyString = value: "'${lib.strings.escape [ "\\" "'" ] value}'";
  ruby =
    value:
    if builtins.isString value then
      rubyString value
    else if builtins.isBool value then
      lib.trivial.boolToString value
    else if builtins.isInt value then
      toString value
    else if builtins.isList value then
      "[${lib.strings.concatMapStringsSep ", " ruby value}]"
    else
      "{ ${
        lib.strings.concatMapAttrsStringSep ", " (name: item: "${rubyString name}: ${ruby item}") (
          lib.attrsets.filterAttrs (_: item: item != null) value
        )
      } }";
  arguments =
    attrs:
    lib.strings.concatMapAttrsStringSep ", "
      (
        name: value:
        "${rubyString name}: ${
          if
            builtins.elem name [
              "link"
              "restart_service"
            ]
            && builtins.isString value
          then
            ":${value}"
          else
            ruby value
        }"
      )
      (
        lib.attrsets.filterAttrs (
          name: value: value != null && !(name == "trusted" && value == false)
        ) attrs
      );
  entry =
    kind: item:
    let
      attrs = removeAttrs item [
        "name"
        "clone_target"
      ];
      args = arguments attrs;
    in
    "${kind} ${rubyString item.name}"
    + lib.strings.optionalString (
      kind == "tap" && (item.clone_target or null) != null
    ) ", ${rubyString item.clone_target}"
    + lib.strings.optionalString (args != "") ", ${args}";
  section =
    name: lines:
    lib.strings.optionalString (lines != [ ]) (
      "# ${name}\n" + lib.strings.concatStringsSep "\n" (lib.lists.unique lines) + "\n\n"
    );
  brewfile = pkgs.writeText "Brewfile" cfg.brewfile;
  brew = "${cfg.prefix}/bin/brew";
  bundle =
    action:
    let
      onlyCheck = builtins.elem action [
        "validate"
        "check"
      ];
      subcommand =
        {
          validate = "list";
          check = "cleanup";
          install = "install";
          cleanup = "cleanup";
        }
        .${action};
      isCleanup = subcommand == "cleanup";
      application = pkgs.writeShellApplication {
        name = "homebrew-${action}";
        runtimeInputs =
          lib.attrsets.attrValues { inherit (cfg) prefix; }
          ++ lib.lists.optional (cfg.mas.apps != { }) pkgs.mas;
        runtimeEnv = activation.extra.env // {
          # Keep cleanup separate so its package scope is explicit
          HOMEBREW_BUNDLE_INSTALL_CLEANUP = "";
          HOMEBREW_BUNDLE_FORCE_INSTALL_CLEANUP = "";
          HOMEBREW_NO_AUTO_UPDATE = if onlyCheck || !activation.auto.update then "1" else "";
        };
        # Environment values and generated arguments are literal strings
        excludeShellChecks = [ "SC2016" ];
        text = ''
          cd "$HOME"
          exec ${
            command (
              [
                brew
                "bundle"
                subcommand
                "--file=${brewfile}"
              ]
              ++ lib.lists.optional (action == "validate") "--all"
              ++ lib.lists.optionals isCleanup (
                map (type: "--${type}") (lib.lists.unique cleanup.types)
                ++ lib.lists.optional (!onlyCheck) "--force"
                ++ lib.lists.optional (!onlyCheck && cleanup.mode == "zap") "--zap"
              )
              ++ lib.lists.optionals (action == "install") (
                [ (if activation.upgrade then "--upgrade" else "--no-upgrade") ] ++ activation.extra.flags
              )
            )
          }
        '';
      };
      user = if cfg.user == null then "" else cfg.user;
    in
    ''
      if /bin/launchctl print "gui/$(id --user -- ${lib.strings.escapeShellArg user})" >/dev/null 2>&1; then
        ${
          (
            # Brew uses these markers to choose user/* even inside a GUI session
            shell.asUser user (
              [ "/usr/bin/env" ]
              ++
                lib.lists.concatMap
                  (name: [
                    "-u"
                    name
                  ])
                  [
                    "SUDO_USER"
                    "HOMEBREW_SUDO_USER"
                    "SSH_TTY"
                    "HOMEBREW_SSH_TTY"
                  ]
              ++ [ (lib.meta.getExe application) ]
            )
          )
        }
      else
        ${
          (command [
            "/usr/bin/sudo"
            "--non-interactive"
            "--user=${user}"
            "--set-home"
            "--"
            (lib.meta.getExe application)
          ])
        }
      fi
    '';
  check = action: message: ''
    if ! homebrew_check_output=$(
      {
        ${bundle action}
      } </dev/null 2>&1
    ); then
      printf >&2 '%s\n%s\n' ${lib.strings.escapeShellArg message} "$homebrew_check_output"
      exit 2
    fi
  '';
in
{
  imports = [ ./options.nix ];
  config = lib.modules.mkMerge [
    {
      homebrew.brewfile =
        "# Generated by Darwin\n\n"
        + section "Taps" (map (entry "tap") cfg.taps)
        + section "Arguments for all casks" (
          lib.lists.optional (cfg.cask.args != { }) "cask_args ${arguments cfg.cask.args}"
        )
        + section "Formulae" (map (entry "brew") cfg.brews)
        + section "Casks" (map (entry "cask") cfg.casks)
        + section "Mac App Store apps" (
          lib.attrsets.mapAttrsToList (name: id: "mas ${rubyString name}, id: ${toString id}") cfg.mas.apps
        )
        + section "Visual Studio Code extensions" (map (name: "vscode ${rubyString name}") cfg.vscode)
        + section "Go packages" (map (name: "go ${rubyString name}") cfg.go.packages)
        + section "Cargo packages" (map (entry "cargo") cfg.cargo.packages)
        + section "uv tools" (map (entry "uv") cfg.uv.tools)
        + section "npm packages" (map (name: "npm ${rubyString name}") cfg.npm.packages)
        + section "Krew plugins" (map (name: "krew ${rubyString name}") cfg.krew.plugins)
        + cfg.extra.config;
    }
    (lib.modules.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.user != null && cfg.user != "root";
          message = "Set homebrew.user or system.primary.user to the non-root owner of Homebrew";
        }
      ];
      system.build.brewfile = brewfile;
      environment.variables = {
        HOMEBREW_BUNDLE_FILE = lib.modules.mkIf cfg.global.brewfile (toString brewfile);
        HOMEBREW_NO_AUTO_UPDATE = lib.modules.mkIf (!cfg.global.auto.update) "1";
      };
      programs.bash.init.extra = lib.modules.mkIf cfg.bash.integration.enable (
        lib.modules.mkOrder 90 ''
          if [[ -x ${lib.strings.escapeShellArg brew} ]]; then
            eval "$(${
              command [
                brew
                "shellenv"
                "bash"
              ]
            })"
            if [[ -r ${lib.strings.escapeShellArg "${cfg.prefix}/etc/profile.d/bash_completion.sh"} ]]; then
              source ${lib.strings.escapeShellArg "${cfg.prefix}/etc/profile.d/bash_completion.sh"}
            else
              for completion in ${lib.strings.escapeShellArg "${cfg.prefix}/etc/bash_completion.d/"}*; do
                if [[ -r $completion ]]; then
                  source "$completion";
                fi
              done
              unset completion
            fi
          fi
        ''
      );
      programs.zsh.init.content = lib.modules.mkIf cfg.zsh.integration.enable (
        lib.modules.mkOrder 515 ''
          if [[ -x ${lib.strings.escapeShellArg brew} ]]; then
            eval "$(${
              command [
                brew
                "shellenv"
                "zsh"
              ]
            })"
          fi
        ''
      );
      system.activation.steps = {
        homebrew = {
          deps = [ "launchd" ];
          checks = ''
            ${failIf "[[ ! -x ${lib.strings.escapeShellArg brew} ]]" "Homebrew must already be installed at ${cfg.prefix}"}
            ${
              command [
                "id"
                "--"
                (if cfg.user == null then "" else cfg.user)
              ]
            } >/dev/null
            ${check "validate" "error: Homebrew Brewfile validation failed"}
            ${lib.strings.optionalString (cleanup.mode == "check") (
              check "check" "error: Homebrew cleanup check failed"
            )}
          '';
          text = ''
            printf 'Homebrew bundle...\n'
            ${bundle "install"}
            ${lib.strings.optionalString
              (builtins.elem cleanup.mode [
                "uninstall"
                "zap"
              ])
              ''
                ${bundle "cleanup"}
                ${check "check" "error: Homebrew cleanup verification failed"}
              ''
            }
          '';
        };
        extra.deps = [ "homebrew" ];
      };
    })
  ];
}

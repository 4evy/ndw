{ config, lib, ... }:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.homebrew;
  nullable = lib.darwin.options.mkNullableOption;
  strings = mkDefaultOption (lib.types.listOf lib.types.str) [ ];
  caskArgs = lib.types.attrsOf (lib.types.either lib.types.str lib.types.bool);
  entries =
    options: description:
    lib.options.mkOption {
      type = lib.types.listOf (
        lib.types.coercedTo lib.types.str (name: { inherit name; }) (
          lib.types.submodule {
            options = {
              name = lib.options.mkOption {
                type = lib.types.nonEmptyStr;
                description = "Homebrew entry name.";
              };
            }
            // options;
          }
        )
      );
      default = [ ];
      inherit description;
    };
  trusted =
    default:
    mkDefaultOption lib.types.bool default ''
      Trust this formula or cask when its name includes a tap. Unqualified
      names require trust on the tap instead. Only trust sources you control
      or have reviewed.
    '';
  tapTrust = lib.types.submodule {
    options =
      lib.attrsets.genAttrs
        [
          "formula"
          "formulae"
          "cask"
          "casks"
          "command"
          "commands"
        ]
        (
          name:
          nullable (lib.types.either lib.types.str (lib.types.listOf lib.types.str)) "Names of ${name} to trust within this tap."
        );
  };
  postinstall = nullable lib.types.str "Shell command run after installation or upgrade.";
in
{
  options.homebrew = {
    enable = lib.options.mkEnableOption "Homebrew Bundle management using an existing Homebrew installation";
    user =
      mkDefaultOption (lib.types.nullOr lib.types.nonEmptyStr) config.system.primary.user
        "Existing user who owns Homebrew. Must be set when Homebrew is enabled."
      // {
        defaultText = lib.options.literalExpression "config.system.primary.user";
      };
    prefix = mkDefaultOption (lib.types.addCheck lib.types.str (
      value: lib.strings.hasPrefix "/" value
    )) "/opt/homebrew" "Existing Homebrew prefix, as reported by brew --prefix.";
    bash.integration.enable = lib.options.mkEnableOption "Homebrew environment and completions in Bash";
    zsh.integration.enable = lib.options.mkEnableOption "Homebrew environment and completions in Zsh";
    on.activation = {
      cleanup =
        mkDefaultOption
          (lib.types.coercedTo lib.types.str (mode: { inherit mode; }) (
            lib.types.submodule {
              options = {
                mode =
                  mkDefaultOption
                    (lib.types.enum [
                      "none"
                      "check"
                      "uninstall"
                      "zap"
                    ])
                    "none"
                    ''
                      Treatment of selected packages absent from the Brewfile.
                      none preserves them, check aborts before activation if any
                      are found, uninstall removes them, and zap also removes
                      associated cask files and user data.
                    '';
                types =
                  mkDefaultOption
                    (lib.types.addCheck (lib.types.listOf (
                      lib.types.enum [
                        "formula"
                        "cask"
                        "tap"
                        "mas"
                        "vscode"
                        "go"
                        "cargo"
                        "uv"
                        "npm"
                        "krew"
                      ]
                    )) (values: values != [ ]))
                    [
                      "formula"
                      "cask"
                      "tap"
                    ]
                    ''
                      Native Bundle package types checked or removed by cleanup.
                      Selected types include packages installed outside this module.
                      Mac App Store apps and other extensions are preserved unless
                      explicitly selected. Regardless of selected types, Homebrew
                      also cleans cached files and old versions, may autoremove
                      unused formula dependencies, and replaces its global trust
                      store with the Brewfile's trust declarations.
                    '';
              };
            }
          ))
          { }
          ''
            Cleanup policy and package scope. A string sets only the mode.
            Cleanup runs separately after a successful installation so its scope
            also applies when Homebrew adds support for other package managers.
            A read-only check then aborts activation if Homebrew still reports
            packages to remove or the cleanup result cannot be verified.
          ''
        // {
          example = {
            mode = "uninstall";
            types = [
              "formula"
              "cask"
              "tap"
              "vscode"
            ];
          };
        };
      auto.update =
        mkDefaultOption lib.types.bool false
          "Allow Homebrew to update its metadata during activation.";
      upgrade = mkDefaultOption lib.types.bool false ''
        Upgrade already installed packages during activation, overriding
        HOMEBREW_BUNDLE_NO_UPGRADE when enabled. Disabling this only skips
        brew upgrade. Installation may still upgrade required dependencies,
        and Homebrew Bundle does not provide version pinning or lockfiles.
      '';
      extra.env = mkDefaultOption (lib.types.addCheck (lib.types.attrsOf lib.types.str) (
        values: lib.lists.all lib.strings.isValidPosixName (builtins.attrNames values)
      )) { } "Environment variables passed to Homebrew checks and activation.";
      extra.flags =
        mkDefaultOption
          (lib.types.listOf (
            lib.types.enum [
              "--debug"
              "-d"
              "--force"
              "-f"
              "--quiet"
              "-q"
              "--verbose"
              "-v"
            ]
          ))
          [ ]
          ''
            Force and logging switches passed to brew bundle install during
            activation. Use these exact spellings as separate list entries.
            Brewfile selection, upgrade and cleanup switches are reserved for
            this module. Configure upgrades through on.activation.upgrade and
            cleanup through on.activation.cleanup.
          ''
        // {
          example = [ "--verbose" ];
        };
    };
    global = {
      brewfile =
        mkDefaultOption lib.types.bool false
          "Use the generated Brewfile for manual brew bundle commands.";
      auto.update =
        mkDefaultOption lib.types.bool true
          "Allow Homebrew to auto-update when run from a managed shell.";
    };
    taps = entries {
      clone_target = nullable lib.types.str "Git URL used instead of the default GitHub URL.";
      force_auto_update = nullable lib.types.bool "Request automatic updates for a non-GitHub tap.";
      trusted =
        mkDefaultOption (lib.types.either lib.types.bool tapTrust) false ''
          Trust this entire tap with true, or only named formulae, casks and
          commands with native Brewfile trust attributes. Prefer trusting
          individual entries to trusting every executable in a tap.
        ''
        // {
          example = {
            formulae = [ "tool" ];
            commands = [ "helper" ];
          };
        };
    } "Repositories to tap, as names or attribute sets. Attributes use native Brewfile names.";
    cask.args = mkDefaultOption caskArgs { } "Native Homebrew options applied to every cask." // {
      example = {
        appdir = "~/Applications";
        require_sha = true;
      };
    };
    greedy.casks = nullable lib.types.bool "Upgrade unversioned and self-updating casks when upgrades are enabled.";
    brews = entries {
      args = nullable (lib.types.listOf lib.types.str) "Install flags without leading dashes.";
      conflicts_with = nullable (lib.types.listOf lib.types.str) "Formulae to unlink and stop before installation.";
      restart_service = nullable (lib.types.either lib.types.bool (
        lib.types.enum [
          "changed"
          "always"
        ]
      )) "Restart the formula's service after installation.";
      start_service = nullable lib.types.bool "Start the formula's service if it is not running.";
      link = nullable (lib.types.either lib.types.bool (
        lib.types.enum [ "overwrite" ]
      )) "Link the formula, optionally overwriting existing links.";
      inherit postinstall;
      version_file = nullable lib.types.str ''
        File to receive the installed formula version. Relative paths resolve
        in the Homebrew user's home directory.
      '';
      trusted = trusted true;
    } "Formulae to install, as names or attribute sets. Attributes use native Brewfile names.";
    casks = entries {
      args = nullable caskArgs "Native Homebrew options for this cask.";
      greedy =
        mkDefaultOption (lib.types.nullOr lib.types.bool) cfg.greedy.casks
          "Upgrade this unversioned or self-updating cask when upgrades are enabled."
        // {
          defaultText = lib.options.literalExpression "config.homebrew.greedy.casks";
        };
      inherit postinstall;
      trusted = trusted true;
    } "Casks to install, as names or attribute sets. Attributes use native Brewfile names.";
    mas.apps =
      mkDefaultOption (lib.types.attrsOf lib.types.ints.positive) { }
        "Mac App Store names mapped to IDs. The Homebrew user must already be signed in.";
    vscode = strings "Editor extensions installed by Homebrew Bundle using a compatible VS Code editor.";
    go.packages =
      mkDefaultOption
        (lib.types.listOf (
          lib.types.addCheck lib.types.nonEmptyStr (name: !(lib.strings.hasInfix "@" name))
        ))
        [ ]
        ''
          Go import paths installed by Homebrew Bundle. Homebrew appends @latest,
          so version suffixes are not supported.
        '';
    cargo.packages = entries {
      source = nullable lib.types.str ''
        Git URL installed with cargo install --git. A branch, tag or revision
        may be selected with ?branch=, ?tag= or ?rev=. Local paths are not
        supported by Homebrew Bundle.
      '';
    } "Cargo crates, as package names or native Brewfile attributes.";
    uv.tools = entries {
      "with" =
        nullable (lib.types.listOf lib.types.str) "Additional requirements installed alongside this uv tool.";
      source = nullable lib.types.str ''
        Remote requirement or Git URL for this uv tool. Local paths are not
        supported by Homebrew Bundle.
      '';
    } "uv tools, as requirement names or native Brewfile attributes.";
    npm.packages = strings "Global npm packages installed by Homebrew Bundle.";
    krew.plugins = strings "Kubectl plugins installed by Homebrew Bundle using Krew.";
    extra.config = mkDefaultOption lib.types.lines "" ''
      Ruby appended verbatim to the generated Brewfile. Homebrew evaluates
      it during preflight validation and cleanup checks as well as install,
      so keep it free of side effects.
    '';
    brewfile = lib.options.mkOption {
      type = lib.types.str;
      readOnly = true;
      internal = true;
      description = "Generated Brewfile content. system.build.brewfile provides its store path when enabled.";
    };
  };
}

{ lib, ... }:
let
  aliases = {
    "environment.systemPackages" = "environment.system.packages";
    "environment.shellAliases" = "environment.shell.aliases";
    "environment.pathsToLink" = "environment.paths.link";
    "environment.extraOutputsToInstall" = "environment.outputs.install";
    "system.primaryUser" = "system.primary.user";
    "system.darwinLabel" = "system.label";
    "system.darwinRevision" = "system.revision";
    "system.configurationRevision" = "system.configuration.revision";
    "programs.bash.shellAliases" = "programs.bash.shell.aliases";
    "programs.bash.enableCompletion" = "programs.bash.completion.enable";
    "programs.zsh.shellAliases" = "programs.zsh.shell.aliases";
    "programs.zsh.enableCompletion" = "programs.zsh.completion.enable";
    "programs.zsh.shellInit" = "programs.zsh.env.extra";
    "programs.zsh.loginShellInit" = "programs.zsh.profile.extra";
    "programs.zsh.histSize" = "programs.zsh.history.size";
    "programs.zsh.histFile" = "programs.zsh.history.path";
    "programs.zsh.enableAutosuggestions" = "programs.zsh.autosuggestion.enable";
    "programs.zsh.enableSyntaxHighlighting" = "programs.zsh.syntax.highlighting.enable";
    "programs.zsh.enableFastSyntaxHighlighting" = "programs.zsh.fast.syntax.highlighting.enable";
    "networking.networkservices" = "networking.knownNetworkServices";
    "system.defaults.dock.expose-group-by-app" = "system.defaults.dock.expose-group-apps";
    "homebrew.enableBashIntegration" = "homebrew.bash.integration.enable";
    "homebrew.enableZshIntegration" = "homebrew.zsh.integration.enable";
    "homebrew.onActivation.autoUpdate" = "homebrew.on.activation.auto.update";
    "homebrew.autoUpdate" = "homebrew.on.activation.auto.update";
    "homebrew.onActivation.upgrade" = "homebrew.on.activation.upgrade";
    "homebrew.onActivation.cleanup" = "homebrew.on.activation.cleanup";
    "homebrew.onActivation.extraEnv" = "homebrew.on.activation.extra.env";
    "homebrew.onActivation.extraFlags" = "homebrew.on.activation.extra.flags";
    "homebrew.global.autoUpdate" = "homebrew.global.auto.update";
    "homebrew.caskArgs" = "homebrew.cask.args";
    "homebrew.greedyCasks" = "homebrew.greedy.casks";
    "homebrew.masApps" = "homebrew.mas.apps";
    "homebrew.goPackages" = "homebrew.go.packages";
    "homebrew.cargoPackages" = "homebrew.cargo.packages";
    "homebrew.extraConfig" = "homebrew.extra.config";
  };
in
{
  imports = lib.attrsets.mapAttrsToList (
    from: to:
    lib.modules.mkAliasOptionModule (lib.strings.splitString "." from) (lib.strings.splitString "." to)
  ) aliases;
}

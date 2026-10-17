# ndw

This is a hard fork of nix-darwin with better activation scripts, system state
handling, and Homebrew support. The Bash and Zsh modules are based on Home
Manager's ones

There's also a macOS settings catalog under `system.settings`. You can use it in
your config or generate scripts from it on its own

**The idea is to keep only the most useful modules here. I mostly care about
making the low-level pieces work well, so you can build your own modules on top.
Everything else is up to you**

There are no docs or tests, and I won't be adding any. I won't be adding more
modules either

I only support macOS 27 (Golden Gate) or newer on Apple Silicon
(`aarch64-darwin`)

## Quick setup

```nix
{
  inputs.ndw.url = "github:4evy/ndw";

  outputs = inputs: {
    darwin.configurations.mac = inputs.ndw.lib.darwin.system {
      modules = [
        {
          system.primary.user = "your-username";
          programs.zsh.enable = true;
        }
      ];
    };
  };
}
```

Run this from the folder with that file. Activation will ask for sudo when it
needs it

```sh
nix run github:4evy/ndw -- switch --flake .#mac
```

After that, open a new shell and use `darwin switch --flake .#mac` to apply
changes

You can also set `determinateNix.enable = true` to let ndw manage Nix, Nixd, and
their launchd services. Install Determinate first, then use your flake for
upgrades once that's enabled

## Old option names

A lot of names use dots now, but these common names still work. They're aliases,
so you can use either spelling without warnings. Other old names may still need
updating

| Alias                               | Dotted name                          |
| ----------------------------------- | ------------------------------------ |
| `environment.systemPackages`        | `environment.system.packages`        |
| `environment.shellAliases`          | `environment.shell.aliases`          |
| `environment.pathsToLink`           | `environment.paths.link`             |
| `environment.extraOutputsToInstall` | `environment.outputs.install`        |
| `system.primaryUser`                | `system.primary.user`                |
| `system.configurationRevision`      | `system.configuration.revision`      |
| `programs.bash.shellAliases`        | `programs.bash.shell.aliases`        |
| `programs.bash.enableCompletion`    | `programs.bash.completion.enable`    |
| `programs.zsh.shellAliases`         | `programs.zsh.shell.aliases`         |
| `programs.zsh.enableCompletion`     | `programs.zsh.completion.enable`     |
| `homebrew.enableBashIntegration`    | `homebrew.bash.integration.enable`   |
| `homebrew.enableZshIntegration`     | `homebrew.zsh.integration.enable`    |
| `homebrew.onActivation.autoUpdate`  | `homebrew.on.activation.auto.update` |
| `homebrew.onActivation.upgrade`     | `homebrew.on.activation.upgrade`     |
| `homebrew.onActivation.cleanup`     | `homebrew.on.activation.cleanup`     |
| `homebrew.onActivation.extraFlags`  | `homebrew.on.activation.extra.flags` |
| `homebrew.global.autoUpdate`        | `homebrew.global.auto.update`        |
| `homebrew.caskArgs`                 | `homebrew.cask.args`                 |
| `homebrew.greedyCasks`              | `homebrew.greedy.casks`              |
| `homebrew.masApps`                  | `homebrew.mas.apps`                  |
| `homebrew.extraConfig`              | `homebrew.extra.config`              |

The rebuild command also accepts `darwinConfigurations` as well as
`darwin.configurations`

## Credits

Based on [nix-darwin](https://github.com/nix-darwin/nix-darwin), with parts
adapted from [Home Manager](https://github.com/nix-community/home-manager).
Thanks to both projects and their contributors

The settings catalog and engine come from SushyDev's
[nix-plist-manager](https://github.com/SushyDev/nix-plist-manager/commit/4ef635b8b2f4c88929ea7d1a8a941acbab5de719)
at the linked revision, with changes for this fork. Thanks to SushyDev for that
work

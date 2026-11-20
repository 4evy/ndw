# ndw

This is a hard fork of nix-darwin with better activation scripts, system state
handling, and Homebrew support. The Bash and Zsh modules are based on Home
Manager's ones

There's also a macOS settings catalog under `system.settings`. You can use it in
your config or generate scripts from it on its own

**The idea is to keep only the most useful modules here. I mostly care about
making the low-level pieces work well, so you can build your own modules on top.
Everything else is up to you**

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

## Optional features

- Install [nh](https://github.com/nix-community/nh) with
  `programs.nh.enable = true`. Set `programs.nh.clean.enable = true` to prune
  old system generations weekly. Keep using `darwin switch` for activation
- Enable Touch ID with `security.pam.services.sudo_local.touchIdAuth = true`.
  Set `reattach = true` in the same block if needed for tmux or screen

## Migrating from nix-darwin

Keep `lib.darwinSystem`, `darwinConfigurations`, and `darwin-rebuild`. See the
[alias map](modules/aliases/aliases.nix) for renamed options

ndw does not provide all upstream services or state-version defaults. It
manages only Determinate Nix, and launchd agents target the primary user

## Credits

Based on [nix-darwin](https://github.com/nix-darwin/nix-darwin), with parts
adapted from [Home Manager](https://github.com/nix-community/home-manager).
Thanks to both projects and their contributors

The settings catalog and engine come from SushyDev's
[nix-plist-manager](https://github.com/SushyDev/nix-plist-manager/commit/4ef635b8b2f4c88929ea7d1a8a941acbab5de719)
at the linked revision, with changes for this fork. Thanks to SushyDev for that
work

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.environment;
  shell = lib.darwin.shell;
  sessionFor =
    variables:
    let
      state = values: lib.attrsets.filterAttrs (name: _: name == "XDG_STATE_HOME") values;
    in
    pkgs.writeText "session" (
      # Apply shell overrides before expanding profile-dependent values, while
      # other shell variables can still extend the shared environment
      shell.exportAll (state cfg.variables)
      + "\n"
      + shell.exportAll (state variables)
      + "\n"
      + shell.exportAll (removeAttrs cfg.variables [ "XDG_STATE_HOME" ])
      + "\n"
      + shell.exportAll (removeAttrs variables [ "XDG_STATE_HOME" ])
    );
in
{
  options.environment = {
    system.packages = mkDefaultOption (lib.types.listOf lib.types.package) [ ] ''
      Packages available to every user through the current system.
      Their application bundles are copied to /Applications/Nix Apps.
    '';
    paths.link =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ]
        "Package directories linked into the system environment.";
    outputs.install =
      mkDefaultOption (lib.types.listOf lib.types.str) [ ]
        "Additional package outputs installed in the system environment.";
    profiles = mkDefaultOption (lib.types.listOf lib.types.str) [ ] ''
      Profiles searched by shells, in PATH order. Shell variables are expanded
      at initialization. The default user profiles include both the legacy
      ~/.nix-profile and the XDG state directory's nix/profile.
    '';
    variables =
      mkDefaultOption lib.darwin.types.shellVariables { }
        "Session variables shared by Bash and Zsh. Shell variable expansion is supported.";
    shell.aliases =
      mkDefaultOption (lib.types.attrsOf lib.types.str) { }
        "Aliases shared by Bash and Zsh.";
    shells =
      mkDefaultOption (lib.types.listOf lib.types.shellPackage) [ ]
        "Additional login shell packages registered in /etc/shells.";
  };
  config = {
    # Use definitions so modules can add paths without dropping the core ones
    environment.paths.link = [
      "/bin"
      "/etc/bash_completion.d"
      "/etc/xdg"
      "/share/man"
      "/share/terminfo"
      "/share/applications"
      "/share/icons"
      "/share/locale"
      "/share/zsh"
      "/share/bash-completion"
    ];
    environment.outputs.install = [ "man" ];
    environment.profiles = lib.modules.mkMerge [
      (lib.modules.mkOrder 800 [
        "$HOME/.nix-profile"
        "\${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile"
      ])
      [
        "/run/current-system/sw"
        "/nix/var/nix/profiles/default"
      ]
    ];
    environment.variables = lib.attrsets.mapAttrs (_: lib.modules.mkDefault) {
      PATH = lib.strings.makeBinPath cfg.profiles + ":/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      NIX_PROFILES = lib.strings.concatStringsSep " " (lib.lists.reverseList cfg.profiles);
      XDG_DATA_DIRS = lib.strings.concatMapStringsSep ":" (path: "${path}/share") cfg.profiles;
      XDG_CONFIG_DIRS = lib.strings.concatMapStringsSep ":" (path: "${path}/etc/xdg") cfg.profiles;
      TERMINFO_DIRS = lib.strings.concatStringsSep ":" (
        map (path: "${path}/share/terminfo") cfg.profiles ++ [ "/usr/share/terminfo" ]
      );
    };
    system.build.environment = pkgs.buildEnv {
      name = "environment";
      paths = cfg.system.packages;
      pathsToLink = cfg.paths.link;
      extraOutputsToInstall = cfg.outputs.install;
      ignoreCollisions = false;
      nativeBuildInputs = lib.attrsets.attrValues { inherit (pkgs) findutils; };
      postBuild = ''
        # Wrapped programs must be invoked through their public wrappers
        if [[ -d $out/bin ]]; then
          find "$out/bin" -maxdepth 1 -name '.*-wrapped' -type l -delete
        fi
      '';
    };
    system.build.session = sessionFor { };
    system.build.sessionFor = sessionFor;
    environment.system.packages = cfg.shells;
    environment.files.shells = lib.modules.mkIf (cfg.shells != [ ]) {
      known.macOS = true;
      text =
        (lib.strings.concatStringsSep "\n") (
          [
            "/bin/bash"
            "/bin/csh"
            "/bin/dash"
            "/bin/ksh"
            "/bin/sh"
            "/bin/tcsh"
            "/bin/zsh"
          ]
          ++ map (package: "/run/current-system/sw${package.shellPath}") cfg.shells
        )
        + "\n";
      known.hashes = [
        # Apple's default /etc/shells
        "9d5aa72f807091b481820d12e693093293ba33c73854909ad7b0fb192c2db193"
      ];
    };
  };
}

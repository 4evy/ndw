{ name, lib, ... }:
let
  inherit (lib.darwin.options) mkDefaultOption mkNullableOption;
in

{
  options =
    let
      inherit (lib) literalExpression mkOption types;
    in
    {
      name = mkDefaultOption types.nonEmptyStr name ''
        The name of the user account. If undefined, the name of the
        attribute set will be used.
      '';

      description =
        mkNullableOption types.nonEmptyStr ''
          A short description of the user account, typically the
          user's full name.

          This defaults to `null` which means, on creation, `sysadminctl`
          will pick the description which is usually always {option}`name`.

          Using an empty name is not supported and breaks macOS like
          making the user not appear in Directory Utility.
        ''
        // {
          example = "Alice Q. User";
        };

      uid = mkOption {
        type = types.ints.unsigned;
        description = "The user's UID.";
      };

      gid = mkDefaultOption types.ints.unsigned 20 "The user's primary group.";

      isHidden = mkDefaultOption types.bool true "Whether to make the user account hidden.";

      home = mkNullableOption types.path ''
        The user's home directory. This defaults to `null`.

        When this is set to `null`, if the user has not been created yet,
        they will be created with the home directory `/var/empty` to match
        the old default.
      '';

      createHome = mkDefaultOption types.bool false "Create the home directory when creating the user.";

      shell =
        mkNullableOption (types.either types.shellPackage types.path) ''
          The user's shell. This defaults to `null`.

          When this is set to `null`, if the user has not been created yet,
          they will be created with the shell `/usr/bin/false` to prevent
          interactive login. If the user already exists, the value is
          considered managed by macOS and `nix-darwin` will not change it.
        ''
        // {
          example = literalExpression "pkgs.bashInteractive";
        };

      ignoreShellProgramCheck = mkDefaultOption types.bool false ''
        By default, nix-darwin will check that programs.SHELL.enable is set to
        true if the user has a custom shell specified. If that behavior isn't
        required and there are custom overrides in place to make sure that the
        shell is functional, set this to true.
      '';

      packages =
        mkDefaultOption (types.listOf types.package) [ ] ''
          The set of packages that should be made available to the user.
          This is in contrast to {option}`environment.system.packages`,
          which adds packages to all users.

          Application bundles are copied into the user's
          `~/Applications/Nix Apps` with the user's ownership. Removed bundles
          are pruned using previous generations' application manifests.
          Unrelated applications are preserved. The account must have a home
          directory, or be created with `createHome` and an explicit `home`.
        ''
        // {
          example = literalExpression "lib.attrsets.attrValues { inherit (pkgs) firefox thunderbird; }";
        };
    };
}

{
  lib,
  nixpkgs,
  revision,
  determinate,
}:
/**
  Evaluate Darwin modules and expose their configuration and system derivation

  The result includes `config`, `options`, `pkgs`, the extended `lib`, and
  `system`, which is `config.system.build.toplevel`. Both `extendModules` and
  its alias `extend.modules` evaluate additional modules and preserve these
  result attributes. Evaluation does not build or activate the system

  Modules receive this library as `lib.darwin`, the built-in modules'
  directory as `modulesPath`, and the pinned Determinate flake as `determinate`

  # Inputs

  `modules`
  : List of module paths, attribute sets, or functions to evaluate

  `special`
  : Optional attribute set, defaulting to `{}`. Its `args` attribute supplies
    extra module arguments, including during import resolution, and defaults
    to `{}`. Arguments may not replace `lib`, `config`, `options`,
    `specialArgs`, `_class`, `_prefix`, or `pkgs`. This restriction also applies
    to the `specialArgs` passed to `extendModules`

  `pkgs`
  : Optional existing `aarch64-darwin` package set, defaulting to `null`.
    When null, import the flake's Nixpkgs input using the module configuration.
    When supplied, configure its settings and overlays before passing it
    rather than setting `nixpkgs.config` or `nixpkgs.overlays` in the modules

  # Type

  ```
  system :: {
    modules :: [Module];
    special? :: { args? :: AttrSet; };
    pkgs? :: Pkgs | Null;
  } -> AttrSet
  ```

  # Examples
  :::{.example}
  ## `lib.darwin.system` usage example

  ```nix
  let
    configuration = inputs.darwin.lib.darwin.system {
      modules = [ { system.label = "workstation"; } ];
    };
    extended = configuration.extendModules {
      modules = [ { programs.zsh.enable = true; } ];
    };
  in
  extended.system
  ```

  :::
*/
{
  modules,
  special ? { },
  pkgs ? null,
}:
let
  # These arguments belong to evalModules or the nixpkgs module
  checkSpecialArgs =
    args:
    assert lib.asserts.assertMsg (builtins.isAttrs args)
      "darwin.system: special arguments must be an attribute set";
    let
      reserved = lib.lists.intersectLists [
        "lib"
        "config"
        "options"
        "specialArgs"
        "_class"
        "_prefix"
        "pkgs"
      ] (builtins.attrNames args);
    in
    assert lib.asserts.assertMsg (reserved == [ ]) ''
      darwin.system: special arguments cannot replace ${lib.strings.concatStringsSep ", " reserved}
      Pass packages through the pkgs argument or nixpkgs.pkgs
    '';
    args;

  result = lib.modules.evalModules {
    class = "darwin";
    specialArgs = {
      modulesPath = toString ../modules;
    }
    // checkSpecialArgs (special.args or { });
    modules = [
      "${nixpkgs}/nixos/modules/misc/assertions.nix"
      ../modules/modules.nix
      {
        _module.args.determinate = determinate;
        nixpkgs.source = lib.modules.mkDefault nixpkgs;
        system.revision = revision;
      }
    ]
    ++ modules
    ++ lib.lists.optional (pkgs != null) { nixpkgs.pkgs = pkgs; };
  };
  expose =
    value:
    let
      extendModules =
        args:
        expose (
          value.extendModules (
            args
            // lib.attrsets.optionalAttrs (args ? specialArgs) {
              specialArgs = checkSpecialArgs args.specialArgs;
            }
          )
        );
    in
    value
    // {
      inherit (value._module.args) pkgs;
      inherit lib extendModules;
      system = value.config.system.build.toplevel;
      extend.modules = extendModules;
    };
in
expose result

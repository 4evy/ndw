{
  config,
  lib,
  pkgs,
  determinate,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.determinateNix;
  t = lib.types;
  json = pkgs.formats.json { };
  # Validate known fields without filling in absent settings or dropping null
  # Nixd falls back to defaults when it cannot parse the configuration
  fields =
    schema: value:
    builtins.isAttrs value
    && lib.lists.all (name: !(builtins.hasAttr name value) || schema.${name} value.${name}) (
      builtins.attrNames schema
    );
  strings = value: builtins.isList value && lib.lists.all builtins.isString value;
  positive = value: builtins.isInt value && value > 0;
  runtimePath =
    value:
    builtins.isString value
    && lib.strings.hasPrefix "/" value
    && value != "/nix/store"
    && !lib.strings.hasPrefix "/nix/store/" value
    && !builtins.hasContext value;
  nixdType = t.addCheck (t.attrsOf json.type) (fields {
    builder = fields {
      state =
        value:
        builtins.elem value [
          "enabled"
          "disabled"
        ];
      cpuCount = positive;
      memoryBytes = positive;
    };
    garbageCollector = fields {
      strategy =
        value:
        builtins.elem value [
          "automatic"
          "disabled"
        ];
    };
    authentication = fields {
      additionalNetrcSources = value: builtins.isList value && lib.lists.all runtimePath value;
    };
    telemetry = fields {
      sentry = fields { endpoint = value: value == null || builtins.isString value; };
    };
    edgeCacheSubstituters = strings;
  });
  singleLine = t.addCheck t.str (value: builtins.match "[^\r\n]*" value != null);
  atom = t.oneOf (
    lib.attrsets.attrVals [
      "bool"
      "int"
      "float"
      "singleLine"
      "path"
      "package"
    ] (t // { inherit singleLine; })
  );
  valueString =
    value:
    if builtins.isBool value then
      lib.trivial.boolToString value
    else if builtins.isFloat value then
      lib.strings.floatToString value
    else if builtins.isList value then
      lib.strings.concatMapStringsSep " " valueString value
    else
      toString value;
  settings = lib.attrsets.filterAttrs (_: value: value != null) cfg.customSettings;
  # Nix requires extra-* settings after their base setting
  render =
    extra:
    lib.generators.toKeyValue { mkKeyValue = name: value: "${name} = ${value}"; } (
      lib.attrsets.mapAttrs (_: valueString) (
        lib.attrsets.filterAttrs (name: _: lib.strings.hasPrefix "extra-" name == extra) settings
      )
    );
  daemonConfig = json.generate "determinate-config.json" cfg.determinateNixd;
  customConfig = pkgs.writeTextFile {
    name = "nix.custom.conf";
    text = config.environment.files."nix/nix.custom.conf".text;
    checkPhase = ''
      ln -s "$out" nix.conf
      if ! diagnostics=$(NIX_CONF_DIR=$PWD NIX_USER_CONF_FILES=/dev/null NIX_CONFIG="" \
        ${cfg.package}/bin/nix --extra-experimental-features nix-command \
        config show --json 2>&1 >/dev/null); then
        printf >&2 '%s\n' "$diagnostics"
        exit 1
      fi
      if [[ -n $diagnostics ]]; then
        printf >&2 '%s\n' "$diagnostics"
        exit 1
      fi
    '';
  };
  nixBin = "${cfg.package}/bin";
  # The mount service must execute before /nix/store is available
  # Its copied executable has only Apple system library dependencies
  bootstrap = "/usr/local/libexec/darwin/${baseNameOf cfg.daemon.package}/determinate-nixd";
  bootstrapPath = builtins.unsafeDiscardStringContext bootstrap;
  initArguments = [
    bootstrapPath
    "--nix-bin"
    (builtins.unsafeDiscardStringContext nixBin)
    "init"
  ];
  limits = {
    NumberOfFiles = 1048576;
    NumberOfProcesses = 1048576;
    Stack = 67108864;
  };
  reserved = [
    "bash-prompt-prefix"
    "external-builders"
    "nix-path"
    "netrc-file"
    "ssl-cert-file"
    "upgrade-nix-store-path-url"
  ];
  command = lib.strings.escapeShellArgs;
  failIf = lib.darwin.shell.failIf;
  readyBin = if cfg.enable then nixBin else "/nix/var/nix/profiles/default/bin";
  restoringInstaller = ''
    jq --exit-status 'any(.[]; .kind == "daemons" and .domain == "system"
      and .user == "" and .label == "systems.determinate.nix-daemon" and .restore != null)' \
      <<< "$launchd_previous_jobs" >/dev/null
  '';
  checkDaemon = ''
    determinate_expected_version=$(NIX_CONF_DIR=/var/empty NIX_USER_CONF_FILES=/dev/null NIX_CONFIG="" ${
      command [
        "${readyBin}/nix-daemon"
        "--version"
      ]
    })
    determinate_store=$(timeout --foreground --kill-after=5 30 ${
      command [
        "${readyBin}/nix"
        "--extra-experimental-features"
        "nix-command"
        "store"
        "info"
        "--json"
        "--store"
        "daemon"
      ]
    })
    ${failIf ''! jq --exit-status --arg version "''${determinate_expected_version##* }" '.version == $version' <<< "$determinate_store" >/dev/null'' "the running Nix daemon does not match the selected runtime"}
  '';
in
{
  options.determinateNix = {
    enable = lib.options.mkEnableOption ''
      declarative Determinate Nix binaries, Nixd, and launchd services on an
      existing Determinate installation. The installer must provision the
      APFS volume, Keychain credentials, and build users first. Do not run
      installer repairs or imperative upgrades after enabling this module.
      Disabling it restores the installer services and their original runtime.
      Activate a prior enabled generation to select its pinned runtime again
    '';
    package =
      mkDefaultOption t.package determinate.inputs.nix.packages.aarch64-darwin.default ''
        Determinate Nix package selected by the pinned Determinate flake input.
        Changing the input or overriding this package selects the runtime for
        the next activation. Previous generations retain their own runtime.
      ''
      // {
        defaultText = lib.options.literalExpression "determinate.inputs.nix.packages.aarch64-darwin.default";
      };
    daemon.package =
      mkDefaultOption t.package determinate.packages.aarch64-darwin.default ''
        Determinate Nixd package. Its executable must be self-contained apart
        from macOS libraries because a versioned copy runs before store mount.
        Keep this compatible with determinateNix.package.
      ''
      // {
        defaultText = lib.options.literalExpression "determinate.packages.aarch64-darwin.default";
      };
    customSettings =
      mkDefaultOption (t.attrsOf (t.nullOr (t.either atom (t.listOf atom)))) { } ''
        Settings written to /etc/nix/nix.custom.conf, included by Nixd's
        generated nix.conf. Lists are space separated, null omits a setting,
        and an empty list clears it. Nixd's certificate, credential, upgrade,
        and external builder settings cannot be overridden here. This file
        is public in the Nix store, so use runtime paths for credentials.
      ''
      // {
        example = lib.options.literalExpression ''
          {
            builders-use-substitutes = true;
            extra-experimental-features = [ "parallel-eval" ];
            extra-substituters = [ "https://cache.example.org" ];
          }
        '';
      };
    determinateNixd =
      mkDefaultOption nixdType { } ''
        JSON configuration for Nixd, written to /etc/determinate/config.json.
        Keys use Nixd's native spelling. Omitted keys keep Nixd defaults and
        explicit null values are preserved, including telemetry.sentry.endpoint
        to disable crash reporting. Authentication sources must be absolute
        runtime paths outside /nix/store. Values are public in the Nix store.
        See https://docs.determinate.systems/determinate-nix/determinate-nixd/.
      ''
      // {
        example = lib.options.literalExpression ''
          {
            builder.state = "disabled";
            garbageCollector.strategy = "disabled";
            telemetry.sentry.endpoint = null;
            authentication.additionalNetrcSources = [ "/etc/determinate/netrc" ];
          }
        '';
      };
  };

  config = lib.modules.mkMerge [
    {
      system.activation.steps = {
        determinate-ready = {
          deps = [ "launchd" ];
          runtimeInputs =
            lib.attrsets.attrValues { inherit (pkgs) jq; } ++ lib.lists.optional cfg.enable cfg.package;
          text =
            if cfg.enable then
              checkDaemon
            else
              ''
                # A disabled generation must verify an installer handback before
                # committing its profile, just as an enabled generation does
                if ${restoringInstaller}then
                  ${checkDaemon}
                fi
              '';
        };
        determinate-handback = lib.modules.mkIf (!cfg.enable) {
          deps = [ "files" ];
          runtimeInputs = lib.attrsets.attrValues { inherit (pkgs) jq; };
          text = ''
            if ${restoringInstaller}then
              # Regenerate the base configuration with the installer runtime
              # before starting its daemon, including on version downgrades
              /usr/local/bin/determinate-nixd --nix-bin /nix/var/nix/profiles/default/bin \
                init --stop-after nix-configuration
            fi
          '';
        };
        launchd = lib.modules.mkIf (!cfg.enable) {
          deps = [ "determinate-handback" ];
          # Discovery in the core launchd checks must run before this check
          checks = lib.modules.mkAfter ''
            if ${restoringInstaller}then
              ${lib.strings.concatMapStringsSep "\n"
                (
                  path:
                  failIf "[[ ! -x ${command [ path ]} ]]" "cannot restore the installer runtime, missing executable: ${path}"
                )
                [
                  "/usr/local/bin/determinate-nixd"
                  "/nix/var/nix/profiles/default/bin/nix"
                  "/nix/var/nix/profiles/default/bin/nix-daemon"
                ]
              }
            fi
          '';
        };
        extra.deps = [ "determinate-ready" ];
      };
    }
    (lib.modules.mkIf cfg.enable {
      assertions = [
        {
          assertion = lib.lists.all (
            name:
            builtins.match "[a-zA-Z][a-zA-Z0-9-]*" name != null
            && !builtins.elem (lib.strings.removePrefix "extra-" name) reserved
            && builtins.match "[^\r\n#]*" (valueString settings.${name}) != null
          ) (builtins.attrNames settings);
          message = "determinateNix.customSettings requires single-line setting names and values and must not override Nixd-managed settings";
        }
      ];

      environment.system.packages = lib.attrsets.attrValues {
        inherit (cfg) package;
        daemon = cfg.daemon.package;
      };
      environment.files = {
        "nix/nix.custom.conf" = {
          text = render false + render true;
          source = customConfig;
        };
        "determinate/config.json".source = daemonConfig;
      };

      # Installer-generated plists from Determinate Nix 3.22.5 are explicit
      # adoption sources, matching nix-installer's macOS job definitions
      # Compare plist values so XML formatting changes do not block adoption
      launchd.daemons = {
        determinate-daemon = {
          enable = true;
          known.sources = [ ./installer/daemon.plist ];
          on.remove.restore = ./installer/daemon.plist;
          restart.triggers = [ config.environment.files."nix/nix.custom.conf".source ];
          config = {
            Label = "systems.determinate.nix-daemon";
            ProgramArguments = [
              "${cfg.daemon.package}/bin/determinate-nixd"
              "--nix-bin"
              nixBin
              "--config-file"
              (toString daemonConfig)
              "daemon"
            ];
            RunAtLoad = true;
            StandardErrorPath = "/var/log/determinate-nix-daemon.log";
            StandardOutPath = "/var/log/determinate-nix-daemon.log";
            SoftResourceLimits = limits;
            HardResourceLimits = limits;
            Sockets =
              lib.attrsets.mapAttrs
                (_: path: {
                  SockFamily = "Unix";
                  SockPassive = true;
                  SockPathName = path;
                })
                {
                  "nix-daemon.socket" = "/var/run/nix-daemon.socket";
                  "determinate-nixd.socket" = "/var/run/determinate-nixd.socket";
                };
          };
        };
        determinate-store = {
          enable = true;
          known.sources = [ ./installer/store.plist ];
          on.remove.restore = ./installer/store.plist;
          wait.for.store = false;
          launcher.enable = false;
          # Run init explicitly during activation, then defer this job to boot
          load.on.activation = false;
          config = {
            Label = "systems.determinate.nix-store";
            ProgramArguments = initArguments;
            RunAtLoad = true;
            StandardErrorPath = "/var/log/determinate-nix-init.log";
            StandardOutPath = "/var/log/determinate-nix-init.log";
          };
        };
        determinate-hook = {
          enable = true;
          known.sources = [ ./installer/hook.plist ];
          on.remove.restore = ./installer/hook.plist;
          wait.for.store = false;
          launcher.enable = false;
          config = {
            Label = "systems.determinate.nix-installer.nix-hook";
            ProgramArguments = [ "/usr/bin/true" ];
            RunAtLoad = true;
          };
        };
      };

      system.activation.steps = {
        determinate = {
          deps = [ "files" ];
          runtimeInputs = lib.attrsets.attrValues {
            inherit (cfg) package;
            inherit (pkgs) cctools;
          };
          checks = ''
              ${failIf "[[ ! -d /nix/var/nix/db || ! -f /etc/fstab ]]" "Determinate Nix must be installed before enabling determinateNix"}
              ${failIf "! /usr/bin/grep -Eq '^[^#]+[[:space:]]/nix[[:space:]]+apfs[[:space:]]' /etc/fstab" "determinateNix requires an existing APFS Nix volume"}
              ${failIf "! /usr/bin/dscl /Local/Default -read /Groups/nixbld >/dev/null 2>&1" "determinateNix requires the installer's nixbld group"}
              ${failIf "[[ -e /Library/LaunchDaemons/org.nixos.nix-daemon.plist ]]" "remove the upstream Nix daemon before enabling Determinate runtime management"}
            ${failIf "/bin/launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1" "unload the upstream Nix daemon before enabling Determinate runtime management"}
            ${failIf "[[ ! -L /nix/var/nix/daemon-socket/socket || $(readlink --canonicalize-missing -- /nix/var/nix/daemon-socket/socket) != $(readlink --canonicalize-missing -- /var/run/nix-daemon.socket) ]]" "the Nix daemon socket must point to /var/run/nix-daemon.socket"}
              # Isolate version discovery from a newer installed configuration
              # that the selected runtime might not understand on a downgrade
              determinate_version=$(NIX_CONF_DIR=/var/empty NIX_USER_CONF_FILES=/dev/null NIX_CONFIG="" ${
                command [
                  "${cfg.package}/bin/nix"
                  "--version"
                ]
              })
              ${failIf "[[ $determinate_version != *'(Determinate Nix '* ]]" "determinateNix.package must provide Determinate Nix"}
              ${lib.strings.concatMapStringsSep "\n"
                (
                  name:
                  failIf "[[ ! -x ${command [ "${cfg.package}/bin/${name}" ]} ]]" "determinateNix.package must provide ${name}"
                )
                [
                  "nix-env"
                  "nix-daemon"
                  "nix-store"
                ]
              }
              /usr/bin/codesign --verify --strict ${command [ "${cfg.daemon.package}/bin/determinate-nixd" ]}
              # The early boot executable must not link against store libraries
              determinate_libraries=$(${lib.meta.getExe' pkgs.cctools "otool"} -L ${
                command [ "${cfg.daemon.package}/bin/determinate-nixd" ]
              })
              ${failIf ''/usr/bin/tail -n +2 <<< "$determinate_libraries" | /usr/bin/grep -Ev "^[[:space:]]+(/usr/lib/|/System/Library/)"'' "Nixd must use only macOS libraries for early boot"}
              ${lib.strings.concatMapStringsSep "\n"
                (path: ''
                  if [[ -e ${command [ path ]} || -L ${command [ path ]} ]]; then
                    ${failIf "[[ -L ${command [ path ]} || ! -d ${command [ path ]} ]]" "Nixd bootstrap parent must be a real directory: ${path}"}
                    determinate_owner=$(stat --format=%u -- ${command [ path ]})
                    determinate_mode=$(stat --format=%a -- ${command [ path ]})
                    ${failIf "[[ $determinate_owner != 0 ]] || (( 8#$determinate_mode & 0022 ))" "Nixd bootstrap parent must be root-owned and writable only by root: ${path}"}
                  fi
                '')
                [
                  "/usr/local"
                  "/usr/local/libexec"
                  "/usr/local/libexec/darwin"
                  (dirOf bootstrapPath)
                ]
              }
              if [[ -e ${command [ bootstrapPath ]} || -L ${command [ bootstrapPath ]} ]]; then
                ${failIf "[[ -L ${command [ bootstrapPath ]} || ! -f ${command [ bootstrapPath ]} || ! -x ${command [ bootstrapPath ]} ]]" "Nixd bootstrap executable must be a regular executable"}
                determinate_owner=$(stat --format=%u -- ${command [ bootstrapPath ]})
                determinate_mode=$(stat --format=%a -- ${command [ bootstrapPath ]})
                ${failIf "[[ $determinate_owner != 0 ]] || (( 8#$determinate_mode & 0022 ))" "Nixd bootstrap executable must be root-owned and writable only by root"}
              fi
          ''
          + lib.strings.concatMapStringsSep "\n" (path: ''
            ${failIf "[[ ! -f ${command [ path ]} ]]" "Nixd authentication source must exist: ${path}"}
            determinate_netrc=$(readlink --canonicalize -- ${command [ path ]})
            ${failIf "[[ $determinate_netrc == /nix/store/* ]]" "Nixd authentication source must resolve outside the Nix store: ${path}"}
          '') (cfg.determinateNixd.authentication.additionalNetrcSources or [ ]);
          text = ''
            # Stop installer repair before it can rewrite the selected services
            if /bin/launchctl print system/systems.determinate.nix-installer.nix-hook >/dev/null 2>&1; then
              launchd_bootout "" system/systems.determinate.nix-installer.nix-hook
            fi
            # Copy into a versioned, root-owned location before installing the
            # mount job. Old copies remain usable by previous generations
            install --directory --mode=755 -- ${command [ (dirOf bootstrapPath) ]}
            if ! cmp --silent -- ${
              command [
                "${cfg.daemon.package}/bin/determinate-nixd"
                bootstrapPath
              ]
            }; then
              (
                determinate_copy=$(${
                  command [
                    "mktemp"
                    "--tmpdir=${dirOf bootstrapPath}"
                    ".nixd.XXXXXXXX"
                  ]
                })
                trap 'rm --force -- "$determinate_copy"' EXIT
                install --mode=755 --no-target-directory -- \
                  ${command [ "${cfg.daemon.package}/bin/determinate-nixd" ]} "$determinate_copy"
                /usr/bin/codesign --verify --strict "$determinate_copy"
                mv --force --no-target-directory -- "$determinate_copy" ${command [ bootstrapPath ]}
              )
            fi
            ${command (
              initArguments
              ++ [
                "--stop-after"
                "nix-configuration"
              ]
            )}
          '';
        };
        launchd.deps = [ "determinate" ];
      };
    })
  ];
}

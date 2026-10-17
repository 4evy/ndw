# Job interface adapted from Home Manager's launchd module
{
  config,
  lib,
  pkgs,
  ...
}:
let
  shell = lib.darwin.shell;
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.launchd;
  functions = import ./functions.nix;
  installJob = pkgs.callPackage ./install.nix { };
  loginUser = if config.system.primary.user == null then "" else config.system.primary.user;
  login = pkgs.callPackage ./login.nix {
    inherit lib functions;
    user = loginUser;
  };
  loginCommand = [
    (lib.meta.getExe' pkgs.coreutils "timeout")
    "--kill-after=5"
    "60"
    (lib.meta.getExe login)
  ];
  plist = pkgs.formats.plist { };
  native = import ./options.nix {
    inherit lib;
    plistType = plist.type;
  };
  environmentType = lib.types.addCheck (lib.types.attrsOf lib.types.str) (
    values:
    lib.lists.all (name: name != "" && !lib.strings.hasInfix "=" name) (builtins.attrNames values)
  );
  job = lib.types.submodule (
    { name, config, ... }: {
      options = {
        enable = lib.options.mkEnableOption "this launchd job";
        load.on.activation = mkDefaultOption lib.types.bool true ''
          Load this job during activation. When disabled, install and enable
          the job but leave it unloaded until the next boot or login.
          Agents whose domain is unavailable are installed and enabled for
          the next login without blocking activation.
          Recovery helpers restore missing user-domain registrations at boot
          and when a graphical session starts.
        '';
        domain = mkDefaultOption (lib.types.enum [
          "gui"
          "user"
        ]) "gui" "Domain used for a user agent.";
        wait.for.store =
          mkDefaultOption lib.types.bool true
            "Wait for the Nix store before starting the job.";
        launcher.name = lib.darwin.options.mkNullableOption lib.types.str "Name displayed for a launcher when store waiting is disabled.";
        launcher.enable = mkDefaultOption lib.types.bool true ''
          Wrap the command with the store-backed launcher. Disable this along
          with wait.for.store for commands that must run before the Nix store
          is mounted. Such jobs must use native config commands, without a
          script or path packages.
        '';
        known.sources = mkDefaultOption (lib.types.listOf lib.types.path) [ ] ''
          Existing plist contents that may be adopted during first activation.
          Adoption requires equivalent plist values. A matching source is also
          used to restore the job if submitting its replacement fails.
        '';
        on.remove.restore = lib.darwin.options.mkNullableOption lib.types.path ''
          Replacement plist installed when this managed job is removed. Its
          label must match this job. The replacement is enabled and started
          when its domain is available. This can return an adopted service to
          its original provider without leaving it stopped.
        '';
        restart.triggers = mkDefaultOption (lib.types.listOf lib.types.path) [ ] ''
          Store paths whose changes require restarting this job. The paths
          become part of the installed job's environment. This does not watch
          mutable files for changes.
        '';
        launcher.shell = mkDefaultOption lib.types.str "/bin/sh" "Interpreter used for the launcher.";
        script = mkDefaultOption lib.types.lines "" "Shell commands used instead of ProgramArguments.";
        path = mkDefaultOption (lib.types.listOf lib.types.package) [ ] "Packages added to the job's PATH.";
        environment.variables = mkDefaultOption environmentType { } "Job environment variables.";
        config = mkDefaultOption (lib.types.submodule native) { } "Native launchd.plist keys.";
        extra.config = lib.options.mkOption {
          type =
            (lib.types.addCheck (lib.types.attrsOf plist.type) (
              extra: lib.lists.all (key: !builtins.hasAttr key native.options) (builtins.attrNames extra)
            ))
            // {
              description = "additional launchd keys without a declared config option";
            };
          default = { };
          description = "Additional native keys without a declared type. Known keys must use config.";
        };
      };
      config.environment.variables.PATH = lib.modules.mkIf (config.path != [ ]) (
        lib.modules.mkDefault (lib.strings.makeBinPath config.path)
      );
      config.environment.variables.DARWIN_RESTART_TRIGGERS = lib.modules.mkIf (
        config.restart.triggers != [ ]
      ) (lib.strings.concatMapStringsSep ":" (path: "${path}") config.restart.triggers);
      config.config = {
        Label = lib.modules.mkDefault "org.nixos.${name}";
        LimitLoadToSessionType = lib.modules.mkIf (config.domain == "user") (
          lib.modules.mkDefault "Background"
        );
        ProgramArguments = lib.modules.mkIf (config.script != "") [
          "${
            pkgs.writeShellApplication {
              name = "job";
              runtimeInputs = config.path;
              text = config.script;
            }
          }/bin/job"
        ];
        EnvironmentVariables = lib.modules.mkIf (config.environment.variables != { }) (
          lib.attrsets.mapAttrs (_: lib.modules.mkDefault) config.environment.variables
        );
      };
    }
  );
  enabled = lib.attrsets.filterAttrs (_: value: value.enable);
  collect =
    kind: user: entries:
    lib.attrsets.mapAttrsToList (
      name: value:
      let
        original = value.config // value.extra.config;
        arguments = if original.ProgramArguments == null then [ ] else original.ProgramArguments;
        command =
          if (original.Program or null) != null then
            [ original.Program ] ++ lib.lists.drop 1 arguments
          else
            arguments;
        # launchd resolves bare executables through _PATH_STDPATH, independently
        # of the job environment. Use Bash explicitly because /bin/sh may
        # select Dash, whose exec has no -a support
        # Keep original arguments in the plist so launchd expands globs before
        # the runner consumes argv[0]. Program stays literal inside the runner
        resolveProgram = ''
          if ! program=$(PATH=/usr/bin:/bin:/usr/sbin:/sbin type -P -- "$program"); then
            printf >&2 'error: executable %s is absent from the standard system path\n' "$argv0"
            exit 127
          fi
        '';
        runner = pkgs.writeText "launchd-exec" ''
          ${
            if arguments != [ ] then
              ''
                argv0=$1
                shift
              ''
            else
              "argv0=${lib.strings.escapeShellArg original.Program}"
          }
          ${
            if original.Program != null then
              "program=${lib.strings.escapeShellArg original.Program}"
            else
              ''
                program=$argv0
                ${
                  if original.EnableGlobbing == true then
                    ''
                      if [[ $program != */* ]]; then
                        ${resolveProgram}
                      fi
                    ''
                  else
                    lib.strings.optionalString (
                      arguments != [ ] && !lib.strings.hasInfix "/" (builtins.head arguments)
                    ) resolveProgram
                }
              ''
          }
          exec -a "$argv0" -- "$program" "$@"
        '';
        invocation = [
          "/bin/bash"
          "-p"
          (toString runner)
        ];
        launcher = value.launcher.name;
        executable = if launcher == null then name else launcher;
        wrapper = pkgs.writeTextFile {
          name = "launcher";
          destination = "/bin/${executable}";
          executable = true;
          text = ''
            #!${value.launcher.shell}
            exec ${lib.strings.escapeShellArgs invocation} "$@"
          '';
        };
        definition =
          if !value.launcher.enable then
            original
          else
            removeAttrs original [
              "Program"
              "ProgramArguments"
            ]
            // {
              ProgramArguments =
                if value.wait.for.store then
                  [
                    "/bin/sh"
                    "-c"
                    ''/bin/wait4path /nix/store && exec "$@"''
                    "launchd"
                  ]
                  ++ invocation
                  ++ arguments
                else
                  [ "${wrapper}/bin/${executable}" ] ++ arguments;
            };
      in
      {
        inherit kind user;
        known = value.known.sources;
        restore = if value.on.remove.restore == null then null else "${value.on.remove.restore}";
        load = value.load.on.activation;
        domain = if kind == "daemons" then "system" else value.domain;
        label = original.Label;
        source = plist.generate "job.plist" definition;
        valid =
          command != [ ]
          && builtins.head command != ""
          && (original.Program == null || lib.strings.hasPrefix "/" original.Program)
          && original.Label != ""
          && !lib.strings.hasInfix "/" original.Label
          && lib.darwin.paths.isFileName executable
          && (value.script == "" || original.Program == null)
          # Early boot jobs cannot depend on the store-backed script runner
          && (value.launcher.enable || (!value.wait.for.store && value.script == "" && value.path == [ ]));
      }
    ) (enabled entries);
  jobs =
    collect "daemons" "" cfg.daemons
    ++ collect "agents" (
      if config.system.primary.user == null then "" else config.system.primary.user
    ) cfg.agents;
  manifest = map (
    item:
    removeAttrs item [
      "valid"
      "load"
      "known"
    ]
  ) jobs;
  command = lib.strings.escapeShellArgs;
  lines = lib.strings.concatStringsSep "\n";
  # Nix selects ownership, destination, and command prefixes for the new jobs
  # Account IDs and home directories belong to the machine being activated
  context =
    item:
    let
      agent = item.kind == "agents";
      prefix = lib.lists.optionals agent [
        "/usr/bin/sudo"
        "--non-interactive"
        "--set-home"
        "--user=${item.user}"
        "--"
      ];
    in
    ''
      ${lib.strings.toShellVars {
        inherit (item) source label;
        # sudo may replace PATH, so these commands must use store paths
        install = prefix ++ [ (lib.meta.getExe installJob) ];
        prepare =
          prefix
          ++ (
            if agent then
              [
                (lib.meta.getExe' pkgs.coreutils "mkdir")
                "--parents"
                "--"
              ]
            else
              [
                (lib.meta.getExe' pkgs.coreutils "install")
                "--directory"
                "--mode=755"
                "--"
              ]
          );
      }}
      ${
        if item.kind == "daemons" then
          ''
            ${lib.strings.toShellVars {
              directory = "/Library/LaunchDaemons";
              domain = "system";
              enableDomain = "system";
              owner = "0";
              launch = [ "/bin/launchctl" ];
            }}
          ''
        else
          ''
            uid=$(${
              command [
                "id"
                "--user"
                "--"
                item.user
              ]
            })
            home=$(${
              command [
                "launchd_home"
                item.user
              ]
            })
            directory="$home/Library/LaunchAgents"
            owner=$uid
            domain=${lib.strings.escapeShellArg item.domain}/"$uid"
            # User and GUI domains share persistent enable state by UID,
            # so agents can be enabled without a graphical login
            enableDomain="user/$uid"
            launch=(/bin/launchctl asuser "$uid" ${
              command [
                "/usr/bin/sudo"
                "--non-interactive"
                "--set-home"
                "--user=${item.user}"
                "--"
                "/bin/launchctl"
              ]
            })
          ''
      }
      target="$directory"/${lib.strings.escapeShellArg "${item.label}.plist"}
      entry=$(launchd_previous ${
        command [
          item.kind
          item.user
          item.label
        ]
      } "$target")
      previous=$(jq --raw-output '.source // ""' <<< "$entry")
      if [[ -f $target ]] && { [[ -z $previous ]] || ! launchd_equal "$previous" "$target"; }; then
        :
        ${lib.strings.concatMapStringsSep "\n" (known: ''
          if launchd_equal ${command [ "${known}" ]} "$target"; then
            entry=${
              lib.strings.escapeShellArg (
                builtins.toJSON {
                  source = "${known}";
                  domain = if item.kind == "daemons" then "system" else item.domain;
                }
              )
            }
          fi
        '') item.known}
      fi
      previous=$(jq --raw-output '.source // ""' <<< "$entry")
    '';
  check = item: ''
    (
      ${context item}
      /usr/bin/plutil -lint -- "$source" >/dev/null
      ${lib.strings.optionalString (item.restore != null) ''
        /usr/bin/plutil -lint -- ${command [ item.restore ]} >/dev/null
        restore_label=$(/usr/bin/plutil -extract Label raw -o - -- ${command [ item.restore ]})
        if [[ $restore_label != "$label" ]]; then
          printf >&2 'error: replacement plist must retain label %s\n' "$label"
          exit 2
        fi
      ''}
      ${lib.strings.optionalString (item.kind == "daemons") ''
        if ! /bin/launchctl print "$domain" >/dev/null; then
          printf >&2 'error: launchd domain %s is unavailable for job %s\n' "$domain" "$label"
          exit 2
        fi
      ''}
      if [[ -e $target || -L $target ]] && ! launchd_equal "$source" "$target"; then
        if [[ -z $previous ]] || ! launchd_equal "$previous" "$target"; then
          printf >&2 'error: refusing to overwrite unmanaged job %s\n' "$target"
          exit 2
        fi
      fi
      if [[ -z $previous && ! -e $target ]] && "''${launch[@]}" print "$domain/$label" >/dev/null 2>&1; then
        printf >&2 'error: refusing to replace loaded unmanaged job %s\n' "$domain/$label"
        exit 2
      fi
    )
  '';
  # TODO: Verify deferred agents across a real logout and login
  apply = item: ''
    (
      ${context item}
      /bin/launchctl enable "$enableDomain/$label"
      ${lib.strings.optionalString (item.kind == "agents") ''
        if ! /bin/launchctl print "$domain" >/dev/null 2>&1; then
          if ! launchd_installed "$source" "$target" "$owner"; then
            "''${prepare[@]}" "$directory"
            "''${install[@]}" "$source" "$target"
          fi
          printf 'Deferring launchd job %s until its domain is available\n' "$domain/$label"
          exit 0
        fi
      ''}
      ${
        if !item.load then
          ''
            # A boot or login job must not run while activation reads old state
            if "''${launch[@]}" print "$domain/$label" >/dev/null 2>&1; then
              launchd_bootout ${lib.strings.escapeShellArg item.user} "$domain/$label"
            fi
            if ! launchd_installed "$source" "$target" "$owner"; then
              "''${prepare[@]}" "$directory"
              "''${install[@]}" "$source" "$target"
            fi
          ''
        else
          ''
            if ! launchd_equal "$source" "$target" || ! "''${launch[@]}" print "$domain/$label" >/dev/null 2>&1; then
              if "''${launch[@]}" print "$domain/$label" >/dev/null 2>&1; then
                launchd_bootout ${lib.strings.escapeShellArg item.user} "$domain/$label"
              fi
              "''${prepare[@]}" "$directory"
              "''${install[@]}" "$source" "$target"
              # Bootstrap success means submission, not service readiness or
              # sustained health. Those properties need job-specific checks
              if ! "''${launch[@]}" bootstrap "$domain" "$target"; then
                ${lib.strings.optionalString (item.kind == "agents") ''
                  if ! /bin/launchctl print "$domain" >/dev/null 2>&1; then
                    printf 'Deferring launchd job %s after its domain disappeared\n' "$domain/$label"
                    exit 0
                  fi
                ''}
                printf >&2 'error: failed to bootstrap launchd job %s\n' "$domain/$label"
                if "''${launch[@]}" print "$domain/$label" >/dev/null 2>&1; then
                  if ! launchd_bootout ${lib.strings.escapeShellArg item.user} "$domain/$label"; then
                    printf >&2 'error: failed to remove partially bootstrapped job %s\n' "$domain/$label"
                    exit 1
                  fi
                fi
                if [[ -n $previous ]]; then
                  previous_domain=$(jq --raw-output '.domain' <<< "$entry")
                  ${lib.strings.optionalString (
                    item.kind == "agents"
                  ) ''previous_domain="$previous_domain/$uid"''}
                  "''${install[@]}" "$previous" "$target"
                  if ! "''${launch[@]}" bootstrap "$previous_domain" "$target"; then
                    printf >&2 'error: failed to restore launchd job %s\n' "$previous_domain/$label"
                  fi
                elif launchd_equal "$source" "$target"; then
                  rm -- "$target"
                fi
                exit 1
              fi
            elif ! launchd_installed "$source" "$target" "$owner"; then
              "''${prepare[@]}" "$directory"
              "''${install[@]}" "$source" "$target"
            fi
          ''
      }
    )
  '';
  # Old owners and paths come from the previous generation, but job kinds are
  # fixed by this module, so generate each cleanup loop with Nix
  prune = kind: ''
    while IFS= read -r -d "" entries \
      && IFS= read -r -d "" domain \
      && IFS= read -r -d "" user \
      && IFS= read -r -d "" label; do
      ${
        if kind == "daemons" then
          ''
            target="/Library/LaunchDaemons/$label.plist"
          ''
        else
          ''
            if ! uid=$(id --user -- "$user") || ! home=$(launchd_home "$user"); then
              printf >&2 'warning: keeping old job %s for unavailable user %s\n' "$label" "$user"
              continue
            fi
            target="$home/Library/LaunchAgents/$label.plist"
            domain="$domain/$uid"
          ''
      }
      owned=false
      while IFS= read -r source; do
        if launchd_equal "$source" "$target"; then
          owned=true; break;
        fi
      done < <(jq --raw-output '.[].source' <<< "$entries")
      if [[ $owned == false ]]; then
        printf >&2 'warning: keeping modified or missing job %s\n' "$target"
        continue
      fi
      if launchd_launch "$user" print "$domain/$label" >/dev/null 2>&1; then
        launchd_bootout "$user" "$domain/$label"
      fi
      restore=$(jq --raw-output --arg source "$source" '
        first(.[] | select(.source == $source)) | .restore // ""
      ' <<< "$entries")
      if [[ -n $restore ]]; then
        ${lib.strings.optionalString (kind == "daemons") ''
          ${lib.meta.getExe installJob} "$restore" "$target"
          /bin/launchctl enable "$domain/$label"
        ''}
        ${lib.strings.optionalString (kind == "agents") ''
          /usr/bin/sudo --non-interactive --set-home --user="$user" -- \
            ${lib.meta.getExe installJob} "$restore" "$target"
          launchd_launch "$user" enable "user/$uid/$label"
          if ! /bin/launchctl print "$domain" >/dev/null 2>&1; then
            continue;
          fi
        ''}
        launchd_launch "$user" bootstrap "$domain" "$target"
      else
        rm -- "$target"
      fi
    done < <(jq --join-output --arg kind ${lib.strings.escapeShellArg kind} \
      --argjson current ${
        lib.strings.escapeShellArg (
          builtins.toJSON (
            map (
              item:
              lib.attrsets.getAttrs [
                "kind"
                "user"
                "label"
                "domain"
              ] item
            ) jobs
          )
        )
      } '
      group_by([.kind, .user, .label, .domain])[]
      | select(.[0].kind == $kind) | .[0] as $old
      | select(any($current[];
          .kind == $old.kind and .user == $old.user
          and .label == $old.label and .domain == $old.domain) | not)
      | tojson, "\u0000", $old.domain, "\u0000",
        $old.user, "\u0000", $old.label, "\u0000"
    ' <<< "$launchd_previous_jobs")
  '';
  environments = {
    system = {
      owner = "";
      variables = cfg.system.environment.variables;
    };
    user = {
      owner = config.system.primary.user;
      variables = cfg.environment.variables;
    };
  };
  setEnvironment = lib.attrsets.mapAttrs (
    scope: environment:
    lines (
      lib.attrsets.mapAttrsToList (
        name: value:
        let
          run =
            args:
            if environment.owner == "" then command args else lib.darwin.shell.asUser environment.owner args;
        in
        lib.strings.optionalString (scope == "user") ''
          # getenv succeeds without output for an unset variable. A sentinel
          # preserves its output newline, distinguishing an empty value and
          # retaining trailing newlines in configured values
          if ! launchd_current_value=$(${
            run [
              "/bin/launchctl"
              "getenv"
              name
            ]
          } && printf .) \
            || [[ $launchd_current_value != ${lib.strings.escapeShellArg (value + "\n.")} ]]; then
            launchd_user_environment_changed=true
          fi
        ''
        + run [
          "/bin/launchctl"
          "setenv"
          name
          value
        ]
      ) environment.variables
    )
  ) environments;
  unsetEnvironment = lib.attrsets.mapAttrsToList (scope: environment: ''
    for previous_system in "''${activation_previous_systems[@]}"; do
      if [[ ! -f $previous_system/launchd/environment.json ]]; then
        continue;
      fi
      while IFS= read -r -d "" owner && IFS= read -r -d "" key; do
        if [[ -n $owner ]] && ! id --user -- "$owner" >/dev/null 2>&1; then
          printf >&2 'warning: keeping environment for unavailable user %s\n' "$owner"
          continue
        fi
        ${lib.strings.optionalString (scope == "user" && environment.owner != null) ''
          if [[ $owner == ${lib.strings.escapeShellArg environment.owner} ]]; then
            if ! launchd_current_value=$(launchd_launch "$owner" getenv "$key" && printf .) \
              || [[ $launchd_current_value != . ]]; then
              launchd_user_environment_changed=true
            fi
          fi
        ''}
        launchd_launch "$owner" unsetenv "$key"
      done < <(jq --join-output ${
        command [
          "--arg"
          "owner"
          (if environment.owner == null then "" else environment.owner)
          "--argjson"
          "keys"
          (builtins.toJSON (builtins.attrNames environment.variables))
          (
            let
              previousOwner = if scope == "system" then ''""'' else ''.owner // ""'';
            in
            ''
              (${previousOwner}) as $previousOwner
              | .${scope} | keys[]
              | select($previousOwner != $owner or (. as $key | $keys | index($key) | not))
              | $previousOwner, "\u0000", ., "\u0000"
            ''
          )
        ]
      } "$previous_system/launchd/environment.json")
    done
  '') environments;

in
{
  options.launchd = {
    stop.timeout = mkDefaultOption lib.types.ints.positive 120 ''
      Maximum seconds to wait for a job to leave launchd during activation.
      If the job remains loaded after a timeout, activation fails and retains
      its recovery journal. The launchctl process is given five additional
      seconds to exit after TERM.
    '';
    agents = mkDefaultOption (lib.types.attrsOf job) { } "Agents installed for system.primary.user.";
    daemons = mkDefaultOption (lib.types.attrsOf job) { } "System launchd daemons.";
    environment.variables = mkDefaultOption environmentType { } ''
      Variables set in the primary user's launchd context. Activation
      and the login helper restart Dock when managed values change so apps
      launched from Dock inherit them. Other running apps retain their
      existing environment until restarted
    '';
    system.environment.variables =
      mkDefaultOption environmentType { }
        "Variables set in root's launchd context during activation and boot.";
  };
  config = {
    # Background agents need registration outside Aqua's discovery domain
    launchd.agents.darwin-login = {
      enable = lib.modules.mkDefault (
        config.system.primary.user != null
        && (
          cfg.environment.variables != { }
          || lib.lists.any (agent: agent.enable && agent.domain == "user") (
            lib.attrsets.attrValues (removeAttrs cfg.agents [ "darwin-login" ])
          )
        )
      );
      load.on.activation = false;
      config = {
        ProgramArguments = loginCommand;
        LimitLoadToSessionType = [
          "Aqua"
          "StandardIO"
        ];
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 30;
      };
    };
    launchd.daemons.darwin-user = {
      enable = lib.modules.mkDefault (cfg.agents.darwin-login.enable or false);
      load.on.activation = false;
      # Enter the user's bootstrap and identity before touching user state
      script = "exec ${shell.asUser loginUser loginCommand}";
      config = {
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 30;
        StandardOutPath = "/var/log/darwin-user-activation.log";
        StandardErrorPath = "/var/log/darwin-user-activation.log";
      };
    };
    assertions = [
      {
        assertion =
          builtins.length jobs
          == builtins.length (lib.lists.unique (map (item: "${item.kind}/${item.label}") jobs));
        message = "Launchd labels must be unique within each job directory";
      }
      {
        assertion =
          (enabled cfg.agents == { } && cfg.environment.variables == { })
          || config.system.primary.user != null;
        message = "Set system.primary.user to configure launchd agents or user environment variables";
      }
    ]
    ++ map (item: {
      assertion = item.valid;
      message = "Launchd jobs require a command, an absolute Program path, and labels and launcher names without slashes";
    }) jobs;
    system.build.launchd = pkgs.linkFarm "launchd" (
      map (item: {
        name = "${item.kind}/${item.label}.plist";
        path = item.source;
      }) jobs
      ++ [
        {
          name = "jobs.json";
          path = (pkgs.formats.json { }).generate "jobs.json" manifest;
        }
        {
          name = "environment.json";
          path = (pkgs.formats.json { }).generate "environment.json" {
            system = cfg.system.environment.variables;
            user = cfg.environment.variables;
            owner = config.system.primary.user;
          };
        }
        {
          name = "restore";
          path = lib.meta.getExe (
            pkgs.callPackage ./restore.nix {
              inherit lib functions;
              user = loginUser;
              environment = cfg.environment.variables;
              jobs = manifest;
            }
          );
        }
      ]
    );
    system.activation.steps.launchd-environment = {
      deps = [ "files" ];
      on.boot = true;
      text = setEnvironment.system;
    };
    system.activation.steps.launchd = {
      deps = [
        "files"
        "launchd-environment"
      ];
      runtimeInputs = lib.attrsets.attrValues { inherit (pkgs) diffutils jq; };
      checks = lines (
        [
          ''
            launchd_manifests=()
            launchd_previous_jobs='[]'
            for previous_system in "''${activation_previous_systems[@]}"; do
              if [[ -f $previous_system/launchd/jobs.json ]]; then
                launchd_manifests+=("$previous_system/launchd/jobs.json")
              else
                if [[ -f $previous_system/systemConfig ]]; then
                  # Upstream records ownership through its immutable job tree
                  # Import only those plists, never arbitrary installed jobs
                  legacy_jobs=$(launchd_legacy_jobs "$previous_system" daemons "" Library/LaunchDaemons)
                  launchd_previous_jobs=$(jq --argjson legacy "$legacy_jobs" '. + $legacy' <<< "$launchd_previous_jobs")
                  ${lib.strings.optionalString (config.system.primary.user != null) ''
                    legacy_jobs=$(launchd_legacy_jobs "$previous_system" agents ${lib.strings.escapeShellArg config.system.primary.user} user/Library/LaunchAgents)
                    launchd_previous_jobs=$(jq --argjson legacy "$legacy_jobs" '. + $legacy' <<< "$launchd_previous_jobs")
                  ''}
                fi
              fi
            done
            if [[ ''${#launchd_manifests[@]} -gt 0 ]]; then
              launchd_previous_jobs=$(jq --slurp --argjson legacy "$launchd_previous_jobs" 'add + $legacy' "''${launchd_manifests[@]}")
            fi
          ''
        ]
        ++ map check jobs
        ++ lib.lists.optional (cfg.environment.variables != { }) ''
          uid=$(${
            command [
              "id"
              "--user"
              "--"
              config.system.primary.user
            ]
          })
          launchd_launch ${lib.strings.escapeShellArg config.system.primary.user} print "user/$uid" >/dev/null
        ''
      );
      functions = ''
        ${functions.equal}
        ${functions.installed}
        launchd_legacy_jobs() {
          local system=$1 kind=$2 user=$3 directory=$4 source label definition
          local entries='[]'
          for source in "$system/$directory/"*.plist; do
            if [[ ! -f $source ]]; then
              continue;
            fi
            definition=$(/usr/bin/plutil -convert json -o - -- "$source") || return
            label=$(jq --exit-status --raw-output '.Label | strings | select(length > 0 and (contains("/") | not))' <<< "$definition") || return
            if [[ ''${source##*/} != "$label.plist" ]]; then
              printf >&2 'error: legacy job filename does not match its label: %s\n' "$source"
              return 2
            fi
            entries=$(jq --arg kind "$kind" --arg user "$user" --arg label "$label" --arg source "$source" '
              . + [{kind: $kind, user: $user, label: $label, source: $source,
                    domain: (if $kind == "daemons" then "system" else "gui" end)}]
            ' <<< "$entries") || return
          done
          printf '%s\n' "$entries"
        }
        launchd_previous() {
          local matches entry source target=$4
          matches=$(jq --compact-output --arg kind "$1" --arg user "$2" --arg label "$3" '
            [.[] | select(.kind == $kind and .user == $user and .label == $label)]
          ' <<< "$launchd_previous_jobs")
          # Prefer the installed version, including one left by a failed attempt
          while IFS= read -r entry; do
            source=$(jq --raw-output '.source' <<< "$entry")
            if launchd_equal "$source" "$target"; then
              printf '%s\n' "$entry"
              return
            fi
          done < <(jq --compact-output '.[]' <<< "$matches")
          jq --compact-output '.[0] // {}' <<< "$matches"
        }
        ${functions.home}
        launchd_launch() {
          local user=$1
          shift
          local launch=(/bin/launchctl)
          if [[ ''${1:-} == bootout ]]; then
            launch=(${lib.meta.getExe' pkgs.coreutils "timeout"} --foreground \
              --kill-after=5 ${toString cfg.stop.timeout} "''${launch[@]}")
          fi
          if [[ -z $user ]]; then
            "''${launch[@]}" "$@"
          else
            local uid
            uid=$(id --user -- "$user") || return
            /bin/launchctl asuser "$uid" /usr/bin/sudo --non-interactive \
              --set-home --user="$user" -- "''${launch[@]}" "$@"
          fi
        }
        launchd_bootout() {
          local user=$1 target=$2
          if ! launchd_launch "$user" bootout --wait "$target"; then
            # Logging out can remove the entire GUI domain during bootout
            if [[ $target == gui/* ]] \
              && ! /bin/launchctl print "''${target%/*}" >/dev/null 2>&1; then
              return 0
            fi
            # The service may have disappeared since the caller checked it
            launchd_launch "$user" print "''${target%/*}" >/dev/null || return
            if launchd_launch "$user" print "$target" >/dev/null 2>&1; then
              return 1
            fi
          fi
        }
      '';
      text = lines (
        [
          ''
            ${lib.strings.optionalString
              (config.system.primary.user != null && config.system.primary.user != "")
              ''
                launchd_user_environment_changed=false
              ''
            }
            (
              ${lines (
                map prune [
                  "daemons"
                  "agents"
                ]
              )}
            )
          ''
        ]
        ++ unsetEnvironment
        ++ [ setEnvironment.user ]
        ++ map apply jobs
      );
    };
  };
}

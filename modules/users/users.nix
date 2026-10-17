{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.darwin.options) mkDefaultOption;
  cfg = config.users;
  command = lib.strings.escapeShellArgs;
  lines = lib.strings.concatStringsSep "\n";
  record = kind: name: "/${kind}/${lib.strings.escape [ "\\" ] name}";
  dscl =
    action: path: args:
    command (
      [
        "/usr/bin/dscl"
        "."
        action
        path
      ]
      ++ args
    );
  managed = names: lib.attrsets.filterAttrs (_: value: builtins.elem value.name names);
  groups = lib.attrsets.attrValues (managed cfg.knownGroups cfg.groups);
  users = lib.attrsets.attrValues (managed cfg.knownUsers cfg.users);
  removed =
    names: values:
    lib.lists.subtractLists (map (value: value.name) (lib.attrsets.attrValues values)) (
      lib.lists.unique names
    );
  deletedGroups = removed cfg.knownGroups cfg.groups;
  deletedUsers = removed cfg.knownUsers cfg.users;
  shellPath =
    value:
    if lib.types.shellPackage.check value then
      "/run/current-system/sw${value.shellPath}"
    else
      toString value;
  validName = name: builtins.match "[^/:[:space:]]+" name != null && !lib.strings.hasPrefix "-" name;
  packageUsers = lib.attrsets.filterAttrs (_: user: user.packages != [ ]) cfg.users;
  readGroup = name: dscl "-read" (record "Groups" name) [ "PrimaryGroupID" ];
  readUser =
    name:
    command [
      "id"
      "--user"
      "--"
      name
    ];
  writeUser =
    user: field: value:
    dscl "-create" (record "Users" user.name) [
      field
      value
    ];
  createGroup = group: ''
    group_id=$(${readGroup group.name} 2>/dev/null) || group_id=
    group_id=''${group_id#PrimaryGroupID: }
    if [[ -z $group_id ]]; then
      ${dscl "-create" (record "Groups" group.name) [
        "PrimaryGroupID"
        group.gid
      ]}
      ${dscl "-create" (record "Groups" group.name) [
        "RealName"
        group.description
      ]}
      group_id=${toString group.gid}
    fi
    if [[ $group_id == ${toString group.gid} ]]; then
      group_members=$(${
        dscl "-read" (record "Groups" group.name) [ "GroupMembership" ]
      } 2>/dev/null) || group_members=
      if [[ $group_members != ${
        lib.strings.escapeShellArg (
          "GroupMembership:"
          + lib.strings.optionalString (group.members != [ ]) (
            " " + lib.strings.concatStringsSep " " group.members
          )
        )
      } ]]; then
        ${dscl "-create" (record "Groups" group.name) ([ "GroupMembership" ] ++ group.members)}
      fi
    else
      printf >&2 'warning: skipping group %s with unexpected GID %s\n' ${lib.strings.escapeShellArg group.name} "$group_id"
    fi
  '';
  createUser = user: ''
    user_id=$(${readUser user.name} 2>/dev/null) || user_id=
    if [[ -n $user_id && $user_id != ${toString user.uid} ]]; then
      printf >&2 'warning: skipping user %s with unexpected UID %s\n' ${lib.strings.escapeShellArg user.name} "$user_id"
    else
      if [[ -z $user_id ]]; then
        ${command (
          [
            "/usr/sbin/sysadminctl"
            "-addUser"
            user.name
            "-UID"
            user.uid
            "-GID"
            user.gid
          ]
          ++ lib.lists.optionals (user.description != null) [
            "-fullName"
            user.description
          ]
          ++ [
            "-home"
            (if user.home == null then "/var/empty" else user.home)
            "-shell"
            (if user.shell == null then "/usr/bin/false" else shellPath user.shell)
          ]
        )}
        # sysadminctl can return success after failing to create the account
        user_id=$(${readUser user.name} 2>/dev/null) || user_id=
        if [[ $user_id != ${toString user.uid} ]]; then
          printf >&2 'error: failed to create user %s, check Directory Services permissions and Full Disk Access\n' ${lib.strings.escapeShellArg user.name}
          exit 2
        fi
        ${lib.strings.optionalString (user.home != null && user.createHome) (command [
          "/usr/sbin/createhomedir"
          "-c"
          "-n"
          "/Local/Default"
          "-u"
          user.name
        ])}
      fi
      ${writeUser user "IsHidden" (if user.isHidden then "1" else "0")}
      ${writeUser user "PrimaryGroupID" user.gid}
      ${lib.strings.optionalString (user.description != null) (
        writeUser user "RealName" user.description
      )}
      ${lib.strings.optionalString (user.shell != null) (
        writeUser user "UserShell" (shellPath user.shell)
      )}
    fi
  '';
  deleteRecord = kind: read: name: ''
    record_id=$(${read name} 2>/dev/null) || record_id=
    record_id=''${record_id#PrimaryGroupID: }
    if [[ -n $record_id ]]; then
      if [[ $record_id =~ ^[0-9]+$ ]] && (( record_id > 501 )); then
        ${dscl "-delete" (record kind name) [ ]}
      else
        printf >&2 'warning: keeping %s with protected or unexpected ID %s\n' ${lib.strings.escapeShellArg "${kind}/${name}"} "$record_id"
      fi
    fi
  '';
in
{
  options.users = {
    knownGroups = mkDefaultOption (lib.types.listOf lib.types.str) [ ] ''
      Groups owned by Darwin. Listed groups are created from users.groups and
      deleted when their configuration is absent. Do not list system groups
    '';
    knownUsers = mkDefaultOption (lib.types.listOf lib.types.str) [ ] ''
      Users owned by Darwin. Listed users are created from users.users and
      deleted when their configuration is absent. Do not list your admin
      account or system users
    '';
    groups = mkDefaultOption (lib.types.attrsOf (
      lib.types.submodule ./group.nix
    )) { } "Group configuration.";
    users = mkDefaultOption (lib.types.attrsOf (
      lib.types.submodule ./user.nix
    )) { } "User configuration.";
    gids =
      mkDefaultOption (lib.types.attrsOf lib.types.str) { }
        "Managed group IDs mapped to configuration keys."
      // {
        internal = true;
      };
    uids =
      mkDefaultOption (lib.types.attrsOf lib.types.str) { }
        "Managed user IDs mapped to configuration keys."
      // {
        internal = true;
      };
  };
  config = {
    assertions = [
      {
        assertion = !(builtins.elem "root" deletedUsers);
        message = "Remove root from users.knownUsers instead of deleting it";
      }
      {
        assertion =
          config.system.primary.user == null || !(builtins.elem config.system.primary.user deletedUsers);
        message = "Remove the primary user from users.knownUsers instead of deleting it";
      }
      {
        assertion = lib.lists.all (
          user: user.name != "root" || user.home == null || user.home == "/var/root"
        ) (lib.attrsets.attrValues cfg.users);
        message = "The root user's home must be null or /var/root";
      }
      {
        assertion = lib.lists.all validName (
          cfg.knownUsers
          ++ cfg.knownGroups
          ++ map (user: user.name) (lib.attrsets.attrValues cfg.users)
          ++ map (group: group.name) (lib.attrsets.attrValues cfg.groups)
        );
        message = "User and group names must be nonempty, must not start with '-', and must not contain slashes, colons, or whitespace";
      }
      {
        assertion =
          let
            names = map (user: user.name) (lib.attrsets.attrValues cfg.users);
          in
          builtins.length names == builtins.length (lib.lists.unique names);
        message = "User account names must be unique";
      }
      {
        assertion =
          let
            names = map (group: group.name) (lib.attrsets.attrValues cfg.groups);
          in
          builtins.length names == builtins.length (lib.lists.unique names);
        message = "Group names must be unique";
      }
    ]
    ++ lib.lists.concatMap (
      user:
      map
        (shell: {
          assertion =
            user.ignoreShellProgramCheck
            || !(builtins.elem (user.shell.pname or null) (
              if shell == "bash" then
                [
                  "bash"
                  "bash-interactive"
                ]
              else
                [ shell ]
            ))
            || config.programs.${shell}.enable;
          message = "Enable programs.${shell}.enable for ${user.name}'s shell, or set users.users.<name>.ignoreShellProgramCheck";
        })
        [
          "bash"
          "zsh"
        ]
    ) (lib.attrsets.attrValues cfg.users);
    warnings = lib.lists.concatMap (
      user:
      lib.lists.optional (
        user.shell.pname or null == "bash"
      ) "Use pkgs.bashInteractive for ${user.name}'s interactive login shell"
    ) (lib.attrsets.attrValues cfg.users);
    users.gids = lib.modules.mkMerge (
      lib.attrsets.mapAttrsToList (key: group: { ${toString group.gid} = key; }) (
        managed cfg.knownGroups cfg.groups
      )
    );
    users.uids = lib.modules.mkMerge (
      lib.attrsets.mapAttrsToList (key: user: { ${toString user.uid} = key; }) (
        managed cfg.knownUsers cfg.users
      )
    );
    environment.shells = lib.lists.filter lib.types.shellPackage.check (
      map (user: user.shell) (lib.attrsets.attrValues cfg.users)
    );
    environment.files = lib.attrsets.mapAttrs' (
      _: user:
      lib.attrsets.nameValuePair "profiles/per-user/${user.name}" {
        source = pkgs.buildEnv {
          name = "user-environment-${user.name}";
          paths = user.packages;
          pathsToLink = config.environment.paths.link;
          extraOutputsToInstall = config.environment.outputs.install;
          inherit (config.system.build.environment) postBuild;
          nativeBuildInputs = lib.attrsets.attrValues { inherit (pkgs) findutils; };
        };
      }
    ) packageUsers;
    environment.profiles = lib.modules.mkIf (packageUsers != { }) (
      lib.modules.mkOrder 900 [ "/etc/profiles/per-user/$USER" ]
    );
    system.activation.steps = {
      groups = {
        deps = [ "files" ];
        # Force the ID maps to detect duplicate IDs before any mutations
        text = builtins.deepSeq cfg.gids (lines (map createGroup groups));
      };
      users = {
        deps = [ "groups" ];
        functions = ''
          users_home() {
            /usr/bin/dscl -plist . -read "$1" NFSHomeDirectory \
              | /usr/bin/plutil -extract 'dsAttrTypeStandard:NFSHomeDirectory.0' raw -o - -
          }
        '';
        checks = lines (
          map (
            user:
            lib.strings.optionalString (user.home != null && user.name != "root") ''
              user_id=$(${readUser user.name} 2>/dev/null) || user_id=
              if [[ $user_id == ${toString user.uid} ]]; then
                home_directory=$(users_home ${lib.strings.escapeShellArg (record "Users" user.name)})
                if [[ $(readlink --canonicalize-missing -- "$home_directory") != $(readlink --canonicalize-missing -- ${lib.strings.escapeShellArg user.home}) ]]; then
                  printf >&2 'error: refusing to change the home directory of existing user %s\n' ${lib.strings.escapeShellArg user.name}
                  exit 2
                fi
              fi
            ''
          ) users
        );
        prepare = lib.strings.optionalString (users != [ ] || deletedUsers != [ ]) ''
          (
            users_permission_required=false
            ${lines (
              map (user: ''
                if ! ${readUser user.name} >/dev/null 2>&1; then
                  users_permission_required=true
                fi
              '') users
              ++ map (name: ''
                user_id=$(${readUser name} 2>/dev/null) || user_id=
                if [[ $user_id =~ ^[0-9]+$ ]] && (( user_id > 501 )); then
                  users_permission_required=true
                fi
              '') deletedUsers
            )}
            if [[ $users_permission_required == true ]]; then
              # An unchanged-value write checks TCC before deployment starts
              # and stays out of the read-only activation checks
              permission_home=$(users_home /Users/nobody)
              if ! /usr/bin/dscl . -change /Users/nobody NFSHomeDirectory \
                "$permission_home" "$permission_home"; then
                printf >&2 'error: account-management permission denied before activation\n'
                printf >&2 'Grant Full Disk Access to the terminal, or enable it for remote users in System Settings > General > Sharing > Remote Login\n'
                exit 2
              fi
            fi
          )
        '';
        text = builtins.deepSeq cfg.uids (
          lines (
            map createUser users
            ++ map (deleteRecord "Users" readUser) deletedUsers
            ++ map (deleteRecord "Groups" readGroup) deletedGroups
          )
        );
      };
      launchd.deps = [ "users" ];
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  plan = import ./applications/plan.nix { inherit lib; };
  deploy = import ./applications/deploy.nix { inherit lib pkgs plan; };
  q = lib.strings.escapeShellArg;
  build =
    name: paths:
    pkgs.buildEnv {
      inherit name paths;
      pathsToLink = [ "/Applications" ];
      # Keep the source available when the final application is removed
      postBuild = ''mkdir -p "$out/Applications"'';
    };
  userApplications = lib.attrsets.mapAttrs' (
    _: user: lib.attrsets.nameValuePair user.name (build "user-applications-${user.name}" user.packages)
  ) config.users.users;
  owners = [
    {
      user = "";
      uid = 0;
      gid = 0;
      source = "${config.system.build.applications}/Applications";
      home = null;
      managed = true;
      createHome = false;
    }
  ]
  ++ lib.attrsets.mapAttrsToList (_: user: {
    user = user.name;
    inherit (user) uid gid createHome;
    home = if user.home == null then null else toString user.home;
    managed = builtins.elem user.name config.users.knownUsers;
    source = "${userApplications.${user.name}}/Applications";
  }) (lib.attrsets.filterAttrs (_: user: user.packages != [ ]) config.users.users);
  inventory =
    source: follow:
    lib.strings.removeSuffix "\n" ''
      find ${if follow then "-L" else "-P"} ${source} -mindepth 1 -maxdepth 1 -printf '%f\0%y\0%U\0' \
        | jq --raw-input --slurp ${q plan.inventory}
    '';
  manifests = map (
    owner:
    pkgs.runCommand "application-owner.json"
      {
        nativeBuildInputs = lib.attrsets.attrValues { inherit (pkgs) findutils jq; };
      }
      ''
        ${inventory (q owner.source) true} \
          | jq --argjson owner ${q (builtins.toJSON owner)} '$owner + {entries: .}' > "$out"
      ''
  ) owners;
  manifest =
    pkgs.runCommand "applications.json"
      {
        nativeBuildInputs = lib.attrsets.attrValues { inherit (pkgs) jq; };
      }
      ''
        jq --slurp . ${lib.strings.escapeShellArgs (map toString manifests)} > "$out"
      '';
in
{
  config = {
    system.build = {
      applications = build "system-applications" config.environment.system.packages;
      inherit userApplications;
      applicationManifest = manifest;
    };
    system.activation.steps.applications = {
      deps = [ "users" ];
      runtimeInputs = lib.attrsets.attrValues { inherit (pkgs) findutils jq; };
      checks = ''
        applications_previous='[]'
        for previous_system in "''${activation_previous_systems[@]}"; do
          if [[ -f $previous_system/applications.json ]]; then
            previous=$(jq --compact-output . "$previous_system/applications.json")
          elif [[ -d $previous_system/Applications ]]; then
            # Import the application tree recorded by older system generations
            previous=$(${inventory ''"$previous_system/Applications"'' true} \
              | jq --arg source "$previous_system/Applications" '[{user: "", uid: 0, gid: 0, source: $source, entries: .}]')
          else
            continue
          fi
          applications_previous=$(jq --argjson previous "$previous" '. + $previous' <<< "$applications_previous")
        done
        if ${plan.legacyLink "'/Applications/Nix Apps'"}; then
          previous=$(${inventory "'/Applications/Nix Apps'" true} \
            | jq '[{user: "", uid: 0, gid: 0, entries: .}]')
          applications_previous=$(jq --argjson previous "$previous" '. + $previous' <<< "$applications_previous")
        fi
        applications_tasks=$(jq --argjson previous "$applications_previous" \
          --arg empty ${q (toString pkgs.emptyDirectory)} ${q plan.tasks} ${manifest})
        applications_plan='[]'
        ${plan.readRecords { entry = "tojson"; } "$applications_tasks" ''
          ${lib.strings.concatMapStringsSep "\n"
            (field: ''${field}=$(jq --raw-output '.${field}' <<< "$entry")'')
            [
              "user"
              "uid"
              "gid"
            ]
          }
          if [[ -z $user ]]; then
            target='/Applications/Nix Apps'
          else
            if actual_uid=$(id --user -- "$user" 2>/dev/null); then
              if [[ $actual_uid != "$uid" ]]; then
                if jq --exit-status '.current' <<< "$entry" >/dev/null; then
                  ${lib.darwin.shell.fail "error: unexpected UID for an application owner"}
                fi
                printf >&2 'warning: keeping applications for replaced user %s\n' "$user"
                continue
              fi
              record=''${user//\\/\\\\}
              home=$(/usr/bin/dscl -plist /Search -read "/Users/$record" NFSHomeDirectory \
                | /usr/bin/plutil -extract 'dsAttrTypeStandard:NFSHomeDirectory.0' raw -o - -)
              if ! jq --exit-status '.managed // false' <<< "$entry" >/dev/null; then gid=$(id --group -- "$user"); fi
            elif jq --exit-status '.current and .managed and .home != null' <<< "$entry" >/dev/null; then
              home=$(jq --raw-output '.home' <<< "$entry")
              ${lib.darwin.shell.failIf ''[[ ! -d $home ]] && ! jq --exit-status '.createHome' <<< "$entry" >/dev/null'' "application owner needs an existing home or createHome"}
            elif jq --exit-status '.current' <<< "$entry" >/dev/null; then
              ${lib.darwin.shell.fail "error: application owner needs an existing home or createHome with an explicit home"}
            else
              printf >&2 'warning: keeping applications for unavailable user %s\n' "$user"
              continue
            fi
            ${lib.darwin.shell.failIf ''[[ $home != /* || $home == *$'\n'* ]]'' "application owner needs an absolute home directory"}
            home=$(readlink --canonicalize-missing -- "$home")
            ${lib.darwin.shell.failIf "[[ $home == / || $home == /private/var/empty || $home == /var/empty ]]" "application owner needs a usable home directory"}
            target="$home/Applications/Nix Apps"
          fi
          parent=$(dirname -- "$target")
          legacy=false
          if ${plan.legacyLink ''"$parent"''} || ${plan.legacyLink ''"$target"''}; then
            legacy=true
            existing='[]'
          elif [[ -L $parent || -L $target || ( -e $parent && ! -d $parent ) || ( -e $target && ! -d $target ) ]]; then
            if jq --exit-status '.entries | length == 0' <<< "$entry" >/dev/null; then continue; fi
            ${lib.darwin.shell.fail "error: application directory was replaced or is an unrelated symlink"}
          elif [[ -d $target ]]; then
            if [[ $(stat --format=%u -- "$target") != "$uid" ]] \
              && jq --exit-status '.entries | length == 0' <<< "$entry" >/dev/null; then continue; fi
            ${lib.darwin.shell.failIf ''[[ $(stat --format=%u -- "$target") != "$uid" ]]'' "application directory has an unexpected owner"}
            existing=$(${inventory ''"$target"'' false})
          else
            existing='[]'
          fi
          entry=$(jq --arg target "$target" --argjson gid "$gid" '. + {target: $target, gid: $gid}' <<< "$entry" \
            | jq --argjson existing "$existing" --argjson legacy "$legacy" ${q plan.reconcile})
          if [[ $legacy == true ]] || jq --exit-status '.names | length > 0' <<< "$entry" >/dev/null; then
            applications_plan=$(jq --argjson entry "$entry" '. + [$entry]' <<< "$applications_plan")
          fi
        ''}
      '';
      inherit (deploy) prepare;
      text =
        deploy.text
        + lib.strings.optionalString (config.system.primary.user != null) ''
          # Retire historical user links after the system bundles are available
          record=${q config.system.primary.user}
          record=''${record//\\/\\\\}
          applications_home=$(/usr/bin/dscl -plist /Search -read "/Users/$record" NFSHomeDirectory \
            | /usr/bin/plutil -extract 'dsAttrTypeStandard:NFSHomeDirectory.0' raw -o - -)
          if ${plan.legacyLink ''"$applications_home/Applications"''}; then
            rm -- "$applications_home/Applications"
          elif [[ ! -L $applications_home/Applications ]] \
            && ${plan.legacyLink ''"$applications_home/Applications/Nix Apps"''}; then
            rm -- "$applications_home/Applications/Nix Apps"
          fi
        '';
    };
    system.activation.steps.launchd.deps = [ "applications" ];
  };
}

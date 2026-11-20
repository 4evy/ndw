# shellcheck shell=bash
# darwin: profile-aware activation
# darwin: boot-aware activation
# darwin: check-aware activation

activation_fail() {
  printf >&2 'error: %s\n' "$1"
  exit 2
}

activation_report_stage() {
  local status=$1
  if [[ -n $activation_stage ]]; then
    if (( status == 0 )); then
      printf >&2 'error: activation stopped before completing %s\n' "$activation_stage"
      return 1
    fi
    printf >&2 'error: activation failed during %s (exit %s)\n' "$activation_stage" "$status"
  fi
  return "$status"
}

activation_finish() {
  local status=$1
  activation_report_stage "$status" || status=$?
  if [[ $activation_rooted == true ]]; then
    rm --force -- "$activation_state/incoming" || printf >&2 'warning: could not remove temporary activation root\n'
  fi
  if [[ $activation_journaled == true && $status != 0 ]]; then
    printf >&2 'Retry the switch or activate a known-good generation to reconcile pending changes.\n'
  fi
  exit "$status"
}

activation_read_previous_systems() {
  local previous
  local -A seen=()
  activation_previous_systems=()
  for previous in "$activation_state/current" /run/current-system "$activation_state"/pending/*; do
    if [[ ! -d $previous ]]; then continue; fi
    previous=$(readlink --canonicalize-existing -- "$previous")
    if [[ ! -v 'seen[$previous]' ]]; then
      seen[$previous]=1
      activation_previous_systems+=("$previous")
    fi
  done
}

activation_begin_attempt() {
  local baseline pending="$activation_state/pending/${system##*/}"
  if [[ ! -e $activation_state/current && ! -L $activation_state/current ]]; then
    # Preserve a pre-journal system before the first switch can replace its
    # runtime link or profile. Never adopt a previous failed attempt
    if baseline=$(readlink --canonicalize-existing -- /run/current-system) \
      && [[ -x $baseline/activate ]] && ! activation_is_pending "$baseline"; then
      ln --symbolic --no-target-directory -- "$baseline" "$activation_state/current"
    elif baseline=$(activation_recovery_system "$activation_default_profile" 2>/dev/null) \
      && [[ $baseline != "$system" ]]; then
      ln --symbolic --no-target-directory -- "$baseline" "$activation_state/current"
    fi
  fi
  # Keep failed attempts rooted for ownership reconciliation on the next
  # switch or rollback. This does not undo changes made by arbitrary hooks
  if ! activation_is_pending "$system"; then
    ln --symbolic --no-target-directory -- "$system" "$pending"
  fi
  if [[ ! -L $pending || $(readlink --canonicalize-existing -- "$pending") != "$system" ]]; then
    activation_fail "activation journal contains an unexpected target: $pending"
  fi
  activation_journaled=true
}

# Resolve the containing system, not the symlink to this executable
system=$(readlink --canonicalize-existing -- "$(dirname -- "$0")")
if [[ ! -f $system/files.json || ! -d $system/launchd ]]; then
  activation_fail 'run activate through a built system'
fi
umask 0022
if [[ $(id --user) != 0 ]]; then activation_fail 'activation requires root'; fi

profile='' generation='' check=false boot=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --check) check=true; shift ;;
    --boot) boot=true; shift ;;
    --profile|--generation)
      if [[ $# -lt 2 || -z $2 || $2 == --* ]]; then activation_fail "$1 needs a value"; fi
      if [[ $1 == --profile ]]; then profile=$2; else generation=$2; fi
      shift 2
      ;;
    *) activation_fail 'usage: activate [--check] [--profile PATH [--generation N]]' ;;
  esac
done
if [[ -n $generation && ( -z $profile || ! $generation =~ ^[0-9]+$ ) ]]; then
  activation_fail '--generation requires --profile and a generation number'
fi
if [[ $boot == true && ( $check == true || -n $profile ) ]]; then
  activation_fail '--boot cannot be combined with check or profile options'
fi

# Find Nix without adding the entire current system to the activation PATH
if ! type -P nix-env >/dev/null \
  && nix_env=$(PATH="$activation_nix_path" type -P nix-env); then
  nix_env=$(readlink --canonicalize-existing -- "$nix_env")
  export PATH="$PATH:${nix_env%/*}"
fi
if [[ -n $profile ]]; then
  if ! type -P nix-env >/dev/null; then activation_fail 'profile updates require nix-env in the activation PATH'; fi
  # Canonicalize the directory without following the profile symlink
  profile="$(readlink --canonicalize-missing -- "$(dirname -- "$profile")")/$(basename -- "$profile")"
fi

cd /
activation_stage=
activation_rooted=false
activation_journaled=false
trap 'activation_finish "$?"' EXIT

# This lock coordinates ndw, not external edits or direct nix-env calls
if [[ $check == false ]]; then
  exec 9>>"$activation_lock"
  if ! flock --exclusive --nonblock 9; then activation_fail 'another Darwin activation is in progress'; fi
elif [[ -f $activation_lock ]]; then
  exec 9<"$activation_lock"
  if ! flock --shared --nonblock 9; then activation_fail 'another Darwin activation is in progress'; fi
fi
if [[ -n $generation && $(readlink --canonicalize-existing -- "$profile-$generation-link") != "$system" ]]; then
  activation_fail 'rollback generation does not select this system'
fi
if [[ $boot == true ]]; then
  selected=$(activation_recovery_system "$activation_default_profile")
  if [[ $selected != "$system" ]]; then activation_fail 'boot restoration must select the last successful system'; fi
elif [[ $check == false ]]; then
  activation_stage='rooting the candidate for preflight'
  install --directory --mode=755 -- "$activation_state/pending"
  ln --symbolic --force --no-target-directory -- "$system" "$activation_state/incoming"
  activation_rooted=true
fi
activation_stage='reading previous systems'
activation_read_previous_systems
if [[ $boot == true ]]; then
  :
  # @boot-preflight@
else
  :
  # @preflight@
fi
activation_stage=
if [[ $check == true ]]; then
  printf 'Activation checks passed\n'
  exit 0
fi

if [[ $boot == false ]]; then
  # Do not pass the lock to background processes launched by hooks
  (
    trap 'activation_report_stage "$?" || exit "$?"' EXIT
    # @prepare@
    activation_stage=
  ) 9>&-
  activation_stage='journaling the candidate'
  activation_begin_attempt
  activation_stage=
fi
(
  trap 'activation_report_stage "$?" || exit "$?"' EXIT
  if [[ $boot == true ]]; then
    :
    # @boot-apply@
  else
    :
    # @apply@
  fi
  activation_stage=
) 9>&-

activation_stage='publishing runtime links'
ln --symbolic --force --no-target-directory -- "$system" /run/current-system
ln --symbolic --force --no-target-directory -- /run/current-system "${activation_state%/*}/current-system"
if [[ -n $profile ]]; then
  activation_stage='updating the profile'
  if [[ -n $generation ]]; then
    if [[ $(readlink --canonicalize-existing -- "$profile-$generation-link") != "$system" ]]; then
      activation_fail 'rollback generation changed during activation'
    fi
    nix-env --profile "$profile" --switch-generation "$generation"
  else
    nix-env --profile "$profile" --set "$system"
  fi
fi
if [[ $boot == false ]]; then
  activation_stage='recording the successful system'
  ln --symbolic --force --no-target-directory -- "$system" "$activation_state/current.next"
  mv --force --no-target-directory -- "$activation_state/current.next" "$activation_state/current"
  activation_journaled=false
  activation_stage='cleaning the journal after activation committed'
  rm --force -- "$activation_state"/pending/*
fi
activation_stage=

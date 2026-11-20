# shellcheck shell=bash

activation_is_pending() {
  local attempt="$activation_state/pending/${1##*/}"
  [[ -e $attempt || -L $attempt ]]
}

activation_recovery_system() {
  local selected="$activation_state/current" target fallback=false
  # A broken success marker is not permission to boot a different generation
  if [[ ! -e $selected && ! -L $selected ]]; then
    selected=$1
    fallback=true
  fi
  if ! target=$(readlink --canonicalize-existing -- "$selected") || [[ ! -x $target/activate ]]; then
    printf >&2 'error: no recoverable Darwin system at %s\n' "$selected"
    return 1
  fi
  if [[ $fallback == true ]] && activation_is_pending "$target"; then
    printf >&2 'error: %s selects an uncommitted activation. Retry the switch or select a known-good generation explicitly\n' "$selected"
    return 1
  fi
  printf '%s\n' "$target"
}

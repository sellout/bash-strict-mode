set \
  -o errexit \
  -o errtrace \
  -o nounset \
  -o pipefail

# `inherit_errexit` was only added in Bash 4.4, and MacOS still includes 3.2,
# so it can’t simply be set unconditionally. Try setting it, and just let it go
# if the shell doesn’t support it.
shopt -s inherit_errexit 2> /dev/null || true

## Reports where a command failed, then exits with its status.
##
# shellcheck disable=SC1112 # we like Unicode quotes
bash_strict_mode_report() {
  local status=$1 line=$2 command=$3
  shift 3

  {
    ## In a pipeline, Bash always hands us the last command, even if an earlier
    ## one failed. This collects the positions in the pipeline of any commands
    ## that failed.
    local positions='' count=0 failures=0
    for code in "$@"; do
      count=$((count + 1))
      if [ "$code" -ne 0 ]; then
        failures=$((failures + 1))
        positions="${positions:+$positions, }$count"
      fi
    done

    printf 'Error at %s:%s:\n' "${BASH_SOURCE[1]:-$0}" "$line"

    if [ "$count" -le 1 ] || [ -z "$positions" ]; then
      # No pipeline, just report the failing command.
      printf '  %s\n' "$command"
    elif [ "$positions" = "$count" ]; then
      # Pipeline, but only the last element (which we can name, but which may be
      # duplicated) failed.
      printf '  %s (the last command in the pipeline)\n' "$command"
    else
      # Pipeline, but one or more non-final elements failed.
      local noun="command"
      [ "$failures" -eq 1 ] || noun="commands"
      printf '  %s %s of the pipeline ending with ‘%s’\n' \
        "$noun" "$positions" "$command"
    fi

    printf '  exited with code ‘%s’\n' "$status"

    # Show the stack trace.
    local frame
    for ((frame = 1; frame < ${#FUNCNAME[@]} - 1; frame++)); do
      printf '  in %s, called from %s:%s\n' \
        "${FUNCNAME[frame]}" \
        "${BASH_SOURCE[frame + 1]:-$0}" \
        "${BASH_LINENO[frame]:-?}"
    done
  } >&2

  exit "$status"
}

trap \
  'bash_strict_mode_report "$?" "$LINENO" "$BASH_COMMAND" "${PIPESTATUS[@]}"' \
  ERR

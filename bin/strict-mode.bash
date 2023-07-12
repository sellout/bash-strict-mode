set \
  -o errexit \
  -o nounset \
  -o pipefail

# `inherit_errexit` was only added in Bash 4.4, and MacOS still includes 3.2.
[[ "${BASH_VERSINFO[0]}" -ge 4 && "${BASH_VERSINFO[1]}" -ge 4 ]] \
  && shopt -s inherit_errexit

# shellcheck disable=SC2154 # `s` is assigned, but shellcheck can’t tell.
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

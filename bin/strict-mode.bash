set \
  -o errexit \
  -o nounset \
  -o pipefail

# `inherit_errexit` was only added in Bash 4.4, and MacOS still includes 3.2,
# so it can’t simply be set unconditionally. Try setting it, and just let it go
# if the shell doesn’t support it.
shopt -s inherit_errexit 2> /dev/null || true

# shellcheck disable=SC2154 # `s` is assigned, but shellcheck can’t tell.
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

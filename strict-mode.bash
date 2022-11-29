set -o errexit \
    -o nounset \
    -o pipefail

shopt -s inherit_errexit

# shellcheck disable=SC2154 # `s` is assigned, but shellcheck can’t tell.
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

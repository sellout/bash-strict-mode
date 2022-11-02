set -euo pipefail
shopt -s inherit_errexit
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

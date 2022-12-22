#!/usr/bin/env bash
SCRIPTDIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
# shellcheck source=/dev/null # this is in the wrong place when shellchecked
source "$SCRIPTDIR/../../bin/strict-mode.bash"

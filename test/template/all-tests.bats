bats_require_minimum_version 1.5.0

@test "successful subshell is" {
  run -0 "$BATS_TEST_DIRNAME/null-hypothesis"
  [ "$output" = "meh" ]
}

@test "failing subshell does" {
  run -1 "$BATS_TEST_DIRNAME/null-hypothesis2"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ Error\ on\ line &&
    $output =~ :\ cat\ nothing-here-man ]]
}

@test "set -e stops immediately" {
  run -1 "$BATS_TEST_DIRNAME/set-e"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ Error\ on\ line &&
    $output =~ :\ cat\ nothing-here-man ]]
}

@test "set -u catches undefined variables" {
  run -1 "$BATS_TEST_DIRNAME/set-u"
  [[ $output =~ line &&
    $output =~ :\ undefined:\ unbound\ variable ]]
}

@test "set -o pipefail catches broken pipes" {
  run -1 "$BATS_TEST_DIRNAME/set-o-pipefail"
  [[ $output =~ Error\ on\ line &&
    $output =~ :\ cat ]]
}

@test "errexit catches a failed command substitution" {
  run -1 "$BATS_TEST_DIRNAME/errexit-command-substitution"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ Error\ on\ line &&
    $output =~ :\ RESULT=\$\(cat\ nothing-here-man\) ]]
}

@test "pipefail applies inside a command substitution" {
  run -1 "$BATS_TEST_DIRNAME/pipefail-command-substitution"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ Error\ on\ line &&
    $output =~ :\ RESULT=\$\(cat\ nothing-here-man\ |\ cat\) ]]
}

@test "inherit_errexit aborts the subshell at the failure" {
  run -1 "$BATS_TEST_DIRNAME/inherit_errexit-aborts-subshell"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ Error\ on\ line &&
    $output =~ :\ RESULT=\$\(cat\ nothing-here-man ]]
}

@test "inherit_errexit is what makes that test fail" {
  ## Control for the test above: the same body, but without `inherit_errexit`.
  ## If this doesn’t exit with `0`, then the test above isn’t testing the right
  ## thing.
  # shellcheck disable=SC2016 # `$1` is for the inner shell, not this one.
  run -0 bash -euo pipefail -c \
    'shopt -u inherit_errexit 2>/dev/null || true
     source "$1"' _ \
    "$BATS_TEST_DIRNAME/../../../test/template/inherit_errexit-aborts-subshell.bash"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ kept\ going ]]
}

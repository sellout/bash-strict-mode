bats_require_minimum_version 1.5.0

@test "successful subshell is" {
    run -0 "$BATS_TEST_DIRNAME/null-hypothesis"
    [ "$output" = "meh" ]
}

@test "failing subshell does" {
    run -1 "$BATS_TEST_DIRNAME/null-hypothesis2"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 6:\ cat\ nothing-here-man ]]
}

@test "doesn’t fail without strict mode" {
    run -0 "$BATS_TEST_DIRNAME/no-strict-mode"
}

@test "set -e stops immediately" {
    run -1 "$BATS_TEST_DIRNAME/set-e"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 6:\ cat\ nothing-here-man ]]
}

@test "set -u catches undefined variables" {
    run -1 "$BATS_TEST_DIRNAME/set-u"
    [[ "$output" =~ line\ 7:\ undefined:\ unbound\ variable ]]
}

@test "set -o pipefail catches broken pipes" {
    run -1 "$BATS_TEST_DIRNAME/set-o-pipefail"
    [[ "$output" =~ Error\ on\ line\ 6:\ cat ]]
}

@test "shopt -s inherit_errexit catches broken subshells" {
    run -1 "$BATS_TEST_DIRNAME/shopt-s-inherit_errexit"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 6:\ RESULT=\$\(cat\ nothing-here-man\) ]]
}

@test "inherit_errexit also pipefails" {
    run -1 "$BATS_TEST_DIRNAME/inherit_errexit-pipefail"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 6:\ RESULT=\$\(cat\ nothing-here-man\ |\ cat\) ]]
}

@test "isn’t already in PATH" {
    # Run from somewhere that we’re unlikely to find strict-mode.bash.
    cd "$TMPDIR"
    run -1 "$BATS_TEST_DIRNAME/is-on-path"
    [[ "$output" =~ strict-mode\.bash:\ No\ such\ file\ or\ directory$ ]]
}

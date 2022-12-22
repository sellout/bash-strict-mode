bats_require_minimum_version 1.5.0

@test "doesn’t fail without strict mode" {
    # FIXME: Not sure why I have to disable `errexit` here when the test should
    #        run in its own shell. Either figure out how to remove it or explain
    #        why it needs to be here.
    set +o errexit
    run -0 "$BATS_TEST_DIRNAME/no-strict-mode"
}

@test "isn’t already in PATH" {
    # Run from somewhere that we’re unlikely to find strict-mode.bash.
    cd "$TMPDIR"
    run -1 "$BATS_TEST_DIRNAME/is-on-path"
    [[ "$output" =~ strict-mode\.bash:\ No\ such\ file\ or\ directory$ ]]
}

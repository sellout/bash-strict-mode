bats_require_minimum_version 1.5.0

@test "doesn’t fail without strict mode" {
  run -0 "$BATS_TEST_DIRNAME/no-strict-mode"
}

@test "isn’t already in PATH" {
  # Make sure we don’t silently proceed if we can’t find strict-mode.
  run -1 env PATH="$(dirname -- "$(command -v bash)")" \
    "$BATS_TEST_DIRNAME/is-on-path"
  [[ $output =~ strict-mode\.bash:\ No\ such\ file\ or\ directory$ ]]
}

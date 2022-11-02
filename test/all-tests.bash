# NB: This needs to run via `bats`.
#
# TODO: This relies on the `src` var introduced by Nix. It shouldn’t.

bats_require_minimum_version 1.5.0

@test "successful subshell is" {
    run -0 $src/test/null-hypothesis
    [ "$output" = "meh" ]
}

@test "failing subshell does" {
    run -1 "$src/test/null-hypothesis2"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 5:\ cat\ nothing-here-man ]]
}

@test "doesn’t fail without strict mode" {
    run -0 "$src/test/no-strict-mode"
}

@test "set -e stops immediately" {
    run -1 "$src/test/set-e"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 5:\ cat\ nothing-here-man ]]
}

@test "set -u catches undefined variables" {
    run -1 "$src/test/set-u"
    [[ "$output" =~ line\ 5:\ undefined:\ unbound\ variable ]]
}

@test "set -o pipefail catches broken pipes" {
    run -1 "$src/test/set-o-pipefail"
    [[ "$output" =~ Error\ on\ line\ 5:\ echo\ \"meh\" ]]
}

@test "shopt -s inherit_errexit catches broken subshells" {
    run -1 "$src/test/shopt-s-inherit_errexit"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 5:\ RESULT=\$\(cat\ nothing-here-man\) ]]
}

@test "inherit_errexit also pipefails" {
    run -1 "$src/test/inherit_errexit-pipefail"
    [[ "$output" =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory
       && "$output" =~ Error\ on\ line\ 5:\ RESULT=\$\(cat\ nothing-here-man\ |\ echo\ \"meh\"\) ]]
}

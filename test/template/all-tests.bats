# shellcheck disable=SC1112 # The report uses Unicode quotes
bats_require_minimum_version 1.5.0

## The trap reports three lines – where, what, and the status – so each check
## below matches all three as one pattern. That ties the line number, the
## command and the exit code to each other, so a report that gets any one of
## them wrong fails the check.
##
## The patterns are single-quoted, with the line number substituted into a
## `LINE` placeholder afterwards in order to preserve literal escapes.

## The line of a given command (`$2`) in a given file (`$1`).
line_of() {
  grep -n -x -F -- "$2" "$1" | head -1 | cut -d: -f1
}

@test "successful subshell is" {
  run -0 "$BATS_TEST_DIRNAME/null-hypothesis"
  [ "$output" = "meh" ]
}

@test "failing subshell does" {
  local script="$BATS_TEST_DIRNAME/null-hypothesis2"
  run -1 "$script"
  local pat='Error at .+:LINE:
  cat nothing-here-man
  exited with code ‘1’'
  pat="${pat/LINE/$(line_of "$script" 'eval cat nothing-here-man')}"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ $pat ]]
}

@test "set -e stops immediately" {
  local script="$BATS_TEST_DIRNAME/set-e"
  run -1 "$script"
  local pat='Error at .+:LINE:
  cat nothing-here-man
  exited with code ‘1’'
  pat="${pat/LINE/$(line_of "$script" 'cat nothing-here-man')}"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ $pat ]]
}

@test "set -u catches undefined variables" {
  run -1 "$BATS_TEST_DIRNAME/set-u"
  [[ $output =~ line &&
    $output =~ :\ undefined:\ unbound\ variable ]]
}

@test "set -o pipefail catches broken pipes" {
  local script="$BATS_TEST_DIRNAME/set-o-pipefail"
  run -1 "$script"
  local pat='Error at .+:LINE:
  command 1 of the pipeline ending with ‘cat’
  exited with code ‘1’'
  pat="${pat/LINE/$(line_of "$script" 'eval source nothing-here-man | cat')}"
  [[ $output =~ $pat ]]
}

@test "pipefail names every failing command in the pipeline" {
  local script="$BATS_TEST_DIRNAME/pipefail-names-the-failing-commands"
  run -1 "$script"
  ## The two `cat`s race for stderr, so only the report itself is matched here.
  local pat='Error at .+:LINE:
  commands 1, 2 of the pipeline ending with ‘cat’
  exited with code ‘1’'
  pat="${pat/LINE/$(line_of "$script" 'cat nothing-here-man | cat nothing-here-man-either | cat')}"
  [[ $output =~ $pat ]]
}

@test "errexit catches a failed command substitution" {
  local script="$BATS_TEST_DIRNAME/errexit-command-substitution"
  run -1 "$script"
  local pat='Error at .+:LINE:
  RESULT=\$\(cat nothing-here-man\)
  exited with code ‘1’'
  # shellcheck disable=SC2016 # A literal, not an expression to expand.
  pat="${pat/LINE/$(line_of "$script" 'RESULT=$(cat nothing-here-man)')}"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ $pat ]]
}

@test "pipefail applies inside a command substitution" {
  local script="$BATS_TEST_DIRNAME/pipefail-command-substitution"
  run -1 "$script"
  local pat='Error at .+:LINE:
  RESULT=\$\(eval cat nothing-here-man \| cat\)
  exited with code ‘1’'
  # shellcheck disable=SC2016 # A literal, not an expression to expand.
  pat="${pat/LINE/$(line_of "$script" 'RESULT=$(eval cat nothing-here-man | cat)')}"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ $pat ]]
}

@test "inherit_errexit aborts the subshell at the failure" {
  local script="$BATS_TEST_DIRNAME/inherit_errexit-aborts-subshell"
  run -1 "$script"
  ## `$LINENO` is where the command *ends*, which for a substitution spanning
  ## lines is the closing paren rather than the `RESULT=` that opened it. The
  ## command spans lines in the report too, so the code lands after the end of
  ## it rather than one line down, and is matched separately below.
  local pat='Error at .+:LINE:
  RESULT=\$\(cat nothing-here-man'
  pat="${pat/LINE/$(line_of "$script" ')')}"
  local code='exited with code ‘1’'
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ $pat &&
    $output =~ $code ]]
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

@test "errtrace reports a failure inside a function" {
  local script="$BATS_TEST_DIRNAME/errtrace-reports-inside-function"
  run -1 "$script"
  local pat='Error at .+:LINE:
  cat nothing-here-man
  exited with code ‘1’'
  pat="${pat/LINE/$(line_of "$script" '  cat nothing-here-man')}"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    $output =~ $pat &&
    ! $output =~ kept\ going ]]
}

@test "errtrace is what makes that test report" {
  ## Control for the test above: the same body, reached through the same trap,
  ## but with `errtrace` turned back off. The failure still exits non-zero, but
  ## nothing says where it happened.
  # shellcheck disable=SC2016 # `$1` and `$2` are for the inner shell.
  run -1 bash -c \
    'source "$1"
     set +o errtrace
     source "$2"' _ \
    "$BATS_TEST_DIRNAME/../../../bin/strict-mode.bash" \
    "$BATS_TEST_DIRNAME/../../../test/template/errtrace-reports-inside-function.bash"
  [[ $output =~ ^cat:\ nothing-here-man:\ No\ such\ file\ or\ directory &&
    ! $output =~ Error\ at &&
    ! $output =~ kept\ going ]]
}

@test "the report goes to stderr" {
  run -1 --separate-stderr "$BATS_TEST_DIRNAME/set-e"
  [[ ! $output =~ Error\ at &&
    $stderr =~ Error\ at ]]
}

@test "reports the file where it failed, not the one that was run" {
  local script="$BATS_TEST_DIRNAME/reports-the-file-where-it-failed"
  local helper="$BATS_TEST_DIRNAME/sourced-helper.sh"
  run -1 "$script"
  local pat='Error at .+/sourced-helper\.sh:LINE:
  cat nothing-here-man'
  pat="${pat/LINE/$(line_of "$helper" '  cat nothing-here-man')}"
  [[ $output =~ $pat ]]
}

@test "reports the call trail" {
  local script="$BATS_TEST_DIRNAME/reports-the-call-trail"
  run -1 "$script"
  local pat='  in inner, called from .+:INNER
  in outer, called from .+:OUTER'
  pat="${pat/INNER/$(line_of "$script" '  inner')}"
  pat="${pat/OUTER/$(line_of "$script" 'outer')}"
  [[ $output =~ $pat ]]
}

@test "pipefail places the failing command when it is the last one" {
  local script="$BATS_TEST_DIRNAME/pipefail-places-the-last-command"
  run -1 "$script"
  local pat='Error at .+:LINE:
  cat nothing-here-man \(the last command in the pipeline\)
  exited with code ‘1’'
  pat="${pat/LINE/$(line_of "$script" 'true | cat nothing-here-man')}"
  [[ $output =~ $pat ]]
}

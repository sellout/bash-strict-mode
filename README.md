# [Bash](https://www.gnu.org/software/bash/) strict mode

## usage

This is intended to be sourced into other scripts. I.e., any script should
start with the following three lines:

```bash
#!/usr/bin/env bash
SCRIPTDIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
source "$SCRIPTDIR/../strict-mode.bash"
```

## explanation

Using `/usr/bin/env` in the shebang line makes the script more portable,
finding bash wherever it may live on the system.

Sourcing a file relative to the script is difficult. The second line is a
compact way to do it fairly reliably. We use the name `SCRIPTDIR` because it
matches the special value that [`shellcheck`](https://www.shellcheck.net/) uses
to indicate an import relative to the script (however, the name does not have to
match `shellcheck`, it is just for affinity). Speaking of `shellcheck`, if you
do use it (which we recommend), then you should make sure to pass the `-x`
option, which allows you to import external scripts, and for `shellcheck` to
check those scripts (if you use [the `source-path=SCRIPTDIR`
directive](https://www.shellcheck.net/wiki/Directive)).

If you have some other way of consistently getting a path to the script that
makes more sense in your project, then this part can be changed. E.g.,

```bash
REPODIR="$(git rev-parse --show-toplevel)"
source "$REPODIR/path/to/strict-mode.bash"
```

If you use `shellcheck`, make sure to also change the `source-path` to
match.

Finally, the third line imports this file into the script. You could
alternatively just copy the body of this file into the script, avoiding the
above complexity, but we recommend against it because then scripts tend to
get out of sync as the contents of this file change. This way, they all are
always checked against the same strictness.

Now, to the behavior of this “strict mode”:
* `set -e`: exit if any command has a non-zero exit;
* `set -u`: references to undefined variables are an error;
* `set -o pipefail`: if a command that is not the end of the a pipeline (`|`)
   fails, fail the whole pipeline;
* `shopt -s inherit_errexit`: If a subshell (`$()`) fails, fail the calling
   shell; and
* `trap … ERR`: When an error occurs, report _where_ it occurred.

## extensions

There are other useful things to include in a script preface, but they
aren’t included here for various reasons:
* `IFS=$'\n\t'`: remove space as a field separator – often you want spaces
  preserved, and only newlines or tabs to be used to separate fields. This
  eliminates a common mistake, but it doesn’t actually make bash catch any
  additional bad behavior, so it’s not part of this strict mode.
* `LC_ALL=C`: remove locale-dependence from the script. This is usually what
  you want, but if it were part of strict mode, you would lose the value
  before you could decide you want to keep it, so it’s not included here.

## resources

* [Use Bash Strict Mode (Unless You Love Debugging)](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
* [Bash strict mode and why you should care](https://olivergondza.github.io/2019/10/01/bash-strict-mode.html)
* [Fail Fast Bash Scripting](https://dougrichardson.us/notes/fail-fast-bash-scripting.html)
* [How do I get the directory where a Bash script is located from within the script itself?](https://stackoverflow.com/questions/59895)

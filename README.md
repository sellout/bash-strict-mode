# [Bash](https://www.gnu.org/software/bash/) strict mode

Making shell scripts more robust.

## usage

This is intended to be sourced into other scripts.

If `strict-mode.bash` is in your `PATH` (as it would be if you use the Nix
derivation), then you simply need

```bash
#!/usr/bin/env bash
source strict-mode.bash
```

Otherwise, you need an extra line to tell your script how to find
strict-mode. Some common approaches are to find it relative to the script you
are currently writing[^1], like:

```bash
#!/usr/bin/env bash
SCRIPTDIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
source "$SCRIPTDIR/../strict-mode.bash"
```

or to find it relative to the repo that your scripts are in:

```bash
#!/usr/bin/env bash
REPODIR="$(git rev-parse --show-toplevel)"
source "$REPODIR/path/to/strict-mode.bash"
```

If you are using [`shellcheck`](https://www.shellcheck.net/) then you should
pass it the `-x` option, which allows you to `source` external scripts. If you
are also using a non-`PATH` approach, you will likely have to set shellcheck’s
[`source-path` directive](https://www.shellcheck.net/wiki/Directive)[^2].
`source-path`.

## explanation

The last line enables strict mode. You could alternatively just copy the body of
`strict-mode.bash` into your script, avoiding the above complexity, but we
recommend against it because then scripts tend to get out of sync as the
contents of this file change. By using `source`, all of your scripts are checked
against a consistent strict mode.

Now, to the behavior of this “strict mode”:
* `set -e`: exit immediately if any command has a non-zero exit;
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
  eliminates a common mistake, but it doesn’t actually make Bash catch any
  additional bad behavior, so it’s not part of this strict mode.
* `LC_ALL=C`: remove locale-dependence from the script. This is usually what
  you want, but if it were part of strict mode, you would lose the value
  before you could decide you want to keep it, so it’s not included here.

## resources

* [Use Bash Strict Mode (Unless You Love Debugging)](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
* [Bash strict mode and why you should care](https://olivergondza.github.io/2019/10/01/bash-strict-mode.html)
* [Fail Fast Bash Scripting](https://dougrichardson.us/notes/fail-fast-bash-scripting.html)


[^1]: Sourcing a file relative to the script is difficult. The second line is a
    compact way to do it fairly reliably. See [How do I get the directory where
    a Bash script is located from within the script
    itself?](https://stackoverflow.com/questions/59895) for a lot of discussion
    on this topic.

[^2]: The variable `SCRIPTDIR` above was chosen for affinity with the special
    value that `shellcheck` uses to indicate an import relative to the script
    (however, the name that you use does not have to match `shellcheck`).

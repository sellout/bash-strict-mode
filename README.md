# [Bash](https://www.gnu.org/software/bash/) strict mode

[![Nix CI](https://nix-ci.com/badge/gh:sellout:bash-strict-mode)](https://nix-ci.com/gh:sellout:bash-strict-mode)
[![Project Manager](https://img.shields.io/badge/%20-Project%20Manager-%235277C3?logo=nixos&labelColor=%23cccccc)](https://sellout.github.io/project-manager/)

Write better shell scripts

Making shell scripts more robust.

## usage

The simplest usage is with the included Bash wrapper:

```bash
#!/usr/bin/env strict-bash
```

That requires `strict-bash` to be in your `PATH`, but you can also call it directly from the command line:

```bash
$ path/to/strict-bash some-script.sh
```

**NOTE**: Keep the `/usr/bin/env`. Rewriting that shebang to name `strict-bash` directly, as `#!/path/to/strict-bash`, disables strict mode without saying so. BSD-derived kernels refuse to use a script as a shebang interpreter, failing with `ENOEXEC`, and the result then depends on whatever performed the exec:

- zsh re-execs with the correct interpreter,
- Bash appoints itself the interpreter, and
- `execvp(3)` falls back to `/bin/sh`.

Since `strict-bash` wraps Bash, the script still runs in every one of those cases — just without strict mode, and without an error. Going through `env` avoids this, because `env` performs the second exec itself. See [NixOS/nix#9488](https://github.com/NixOS/nix/issues/9488) for the same problem under `nix run`.

This matters under Nix, where `patchShebangs` performs precisely that rewrite. Where a script’s shebang has to name absolute paths, a shebang may carry one argument, so name Bash and hand it `strict-bash`:

```bash
#!/path/to/bash /path/to/strict-bash
```

However, you can also enable strict mode at the file level by sourcing `strict-mode.bash`. If `strict-mode.bash` is in your `PATH` (as it would be if you use the Nix derivation), then you only need

```bash
#!/usr/bin/env bash
source strict-mode.bash
```

Otherwise, you need an extra line to tell your script how to find strict mode. Some common approaches are to find it relative to the script you are currently writing[^1], like:

```bash
#!/usr/bin/env bash
SCRIPTDIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
source "$SCRIPTDIR/../strict-mode.bash"
```

or to find it relative to the repository that your scripts are in:

```bash
#!/usr/bin/env bash
REPODIR="$(git rev-parse --show-toplevel)"
source "$REPODIR/path/to/strict-mode.bash"
```

If you are using [ShellCheck](https://www.shellcheck.net/) then you should
pass it the `-x` option, which allows you to `source` external scripts. If you
are also using a non-`PATH` approach, you will likely have to set ShellCheck’s
[`source-path` directive](https://www.shellcheck.net/wiki/Directive)[^2].
`source-path`.

### within Nix flakes

```nix
inputs = {
  bash-strict-mode = {
    inputs.nixpkgs.follows = "nixpkgs";
    url = github:sellout/bash-strict-mode;
  };
  ...
};
```

Make `strict-bash` and `strict-mode.bash` available to your derivations.

```nix
outputs = {self, bash-strict-mode, flake-utils, nixpkgs, ...}:
  flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [bash-strict-mode.overlays.default];
    };
  in {
    packages.default = mkDerivation {
      ...
      ### Make strict-bash (and strict-mode.bash) available via PATH.
      nativeBuildInputs = [pkgs.bash-strict-mode];
    };
};
```

Use `strict-bash` instead of `bash` for your derivations’ builds.

```nix
outputs = {self, bash-strict-mode, flake-utils, nixpkgs, ...}:
  flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
      bash-strict-mode.overlays.default
    ];
  in {
    ### Apply strict-bash and shellcheck to all the shell snippets in the
    ### derivation’s build.
    packages.default = pkgs.checkedDrv (mkDerivation {
      ...
    });
};
```

Use `strict-bash` locally, from the upstream flake.

```bash
$ nix run github:sellout/bash-strict-mode someScript
```

## explanation

The last line enables strict mode. You could instead just copy the body of `strict-mode.bash` into your script, avoiding the above complexity. But then scripts tend to get out of sync as the contents of this file change, so we recommend against it. By using `source`, all your scripts get checked against a consistent strict mode.

Now, to the behavior of this “strict mode”:

- `set -e` / `-o errexit`: exit immediately if any command has a non-zero exit;
- `set -u` / `-o nounset`: references to undefined variables are an error;
- `set -o pipefail`: if a command that’s not the end of the a pipeline (`|`) fails, fail the whole pipeline;
- `shopt -s inherit_errexit`: If a sub-shell (`$()`) fails, fail the calling shell; and
- `trap … ERR`: When an error occurs, report _where_ it occurred.

## Often Asked Questions

(FAQ)

<!-- vale Microsoft.FirstPerson = NO -->
<!-- vale Microsoft.HeadingPunctuation = NO -->

### How do I work around <some failure>?

Strict mode can catch you by surprise, complaining about various idioms that you thought were fine for years. Some approaches to avoid those issues are described in [Use Bash Strict Mode (Unless You Love Debugging)](http://redsymbol.net/articles/unofficial-bash-strict-mode/#issues-and-solutions). One that we recommend is to use a sub-shell to scope disabling parts of strict mode. For example,

```bash
<safe code>
(
  set +o nounset
  somethingInvolvingUnsetVars
)
```

If the thing you are scoping involves `source` this might not work as well. You have two options:

1. explicitly disable then re-enable the settings

   ```bash
   set +u
   source has-unset-vars.sh
   set -u
   codeDependingOnSource
   ```

2. include the code that depends on the `source` in the sub-shell

   ```bash
   (
     set +u
     source has-unset-vars.sh
     codeDependingOnSource
   )
   ```

Combining the two is also an option. This should ensure that the scope holds, while still giving you checking on other code that depends on the environment of the sub-shell.

```bash
(
  set +u
  source has-unset-vars.sh
  set -u
  codeDependingOnSource
)
```

<!-- vale Microsoft.FirstPerson = YES -->
<!-- vale Microsoft.HeadingPunctuation = YES -->

## extensions

Other useful things may be included in a script preface, but they aren’t included here for various reasons:

- `IFS=$'\n\t'`: remove space as a field separator – often you want spaces preserved, and only allow newlines or tabs to separate fields. This eliminates a common mistake, but it doesn’t actually make Bash catch any extra bad behavior, so it’s not part of this strict mode.
- `LC_ALL=C`: remove locale-dependence from the script. This is usually what you want, but if it were part of strict mode, you would lose the value before you could decide you want to keep it, so it’s not included here.

## resources

- [Use Bash Strict Mode (Unless You Love Debugging)](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [Bash strict mode and why you should care](https://olivergondza.github.io/2019/10/01/bash-strict-mode.html)
- [Fail Fast Bash Scripting](https://dougrichardson.us/notes/fail-fast-bash-scripting.html)

[^1]: Sourcing a file relative to the script is difficult. The second line is a compact way to do it somewhat reliably. See

<!-- vale Microsoft.FirstPerson = NO -->
<!-- vale Microsoft.Passive = NO -->

    [How do I get the directory where a Bash script is located from within the script itself?](https://stackoverflow.com/questions/59895)

<!-- vale Microsoft.FirstPerson = YES -->
<!-- vale Microsoft.Passive = YES -->

    for a lot of discussion on this topic.

[^2]: The variable `SCRIPTDIR` above has affinity with the special value that `shellcheck` uses to indicate an import relative to the script (however, the name that you use doesn’t have to match `shellcheck`).

## development environment

We recommend the following steps to make working in this repository easier.

### `direnv allow`

This command ensures that any work you do within this repository happens within a consistent reproducible environment. That environment provides various debugging tools, etc. When you leave this directory, you leave that environment behind, so it doesn’t impact anything else on your system.

### `git config --local include.path ../.cache/git/config`

This applies our repository-specific Git configuration to `git` commands run against this repository. It’s lightweight (you should definitely look at it before applying this command) – it does things like telling `git blame` to ignore formatting-only commits.

## building & development

Especially if you are unfamiliar with the bash ecosystem, there is a Nix build (both with and without a flake). If you are unfamiliar with Nix, [Nix adjacent](...) can help you get things working in the shortest time and least effort possible.

### if you have `nix` installed

`nix build` will build and test the project fully.

`nix develop` will put you into an environment where the traditional build tooling works. If you also have `direnv` installed, then you should automatically be in that environment when you're in a directory in this project.

## versioning

In the absolute, almost every change is a breaking change. This section describes how we mitigate that to offer minor updates and revisions.

## comparisons

Other projects similar to this one, and how they differ.

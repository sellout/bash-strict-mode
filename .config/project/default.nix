{
  config,
  flaky,
  lib,
  supportedSystems,
  ...
}: {
  project = {
    name = "bash-strict-mode";
    summary = "Write better shell scripts";
  };

  editorconfig.enable = true;

  programs = {
    direnv.enable = true;
    # This should default by whether there is a .git file/dir (and whether it’s
    # a file (worktree) or dir determines other things – like where hooks
    # are installed.
    git.enable = true;
    treefmt = let
      shellFiles = ["*.bash" "bin/*" "test/*"];
    in {
      enable = true;
      programs = {
        ## Shell linter
        shellcheck.enable = true;
        ## Shell formatter
        shfmt = {
          enable = true;
          ## NB: This has to be unset to allow the .editorconfig
          ##     settings to be used. See numtide/treefmt-nix#96.
          indent_size = null;
        };
      };
      settings.formatter = {
        shellcheck = {
          includes = shellFiles;
          options = ["--external-sources"];
        };
        shfmt.includes = shellFiles;
      };
    };
    vale = {
      enable = true;
      excludes = [
        "./bin/strict-bash"
        "./test/generate"
        "./test/is-on-path"
      ];
    };
  };

  services = {
    flakehub.enable = true;
    garnix.enable = true;
    github = {
      enable = true;
      settings = {
        ## FIXME: Shouldn’t need `mkForce` here (or to duplicate the base
        ##        contexts). Need to improve module merging.
        branches.main.protection.required_status_checks.contexts =
          lib.mkForce
          (flaky.lib.forGarnixSystems supportedSystems (sys: [
            "homeConfig ${sys}-example"
            "package ${config.project.name} [${sys}]"
            "package default [${sys}]"
            ## FIXME: These are duplicated from the base config
            "check formatter [${sys}]"
            "devShell default [${sys}]"
          ]));
        repository.topics = ["bash" "development" "nix-flakes"];
      };
    };
    renovate.enable = true;
  };
}

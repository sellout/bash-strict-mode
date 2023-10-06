{config, flaky, lib, ...}: {
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
  };

  services = {
    flakehub.enable = true;
    garnix = {
      enable = true;
      builds.exclude = [
        # TODO: Remove once garnix-io/garnix#285 is fixed.
        "homeConfigurations.x86_64-darwin-${config.project.name}-example"
      ];
    };
    github = {
      enable = true;
      settings = {
        repository.topics = ["bash" "development" "nix-flakes"];
        ## FIXME: Shouldn’t need `mkForce` here (or to duplicated the base
        ##        contexts). Need to improve module merging.
        branches.main.protection.required_status_checks.contexts = lib.mkForce
          (lib.concatMap flaky.lib.garnixChecks [
            (sys: "homeConfig ${sys}-${config.project.name}-example")
            (sys: "package ${config.project.name} [${sys}]")
            (sys: "package default [${sys}]")
            ## FIXME: These are duplicated from the base config
            (sys: "check formatter [${sys}]")
            (sys: "devShell default [${sys}]")
          ]);
      };
    };
    renovate.enable = true;
  };
}

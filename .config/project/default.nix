### All available options for this file are listed in
### https://sellout.github.io/project-manager/options.xhtml
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

  programs = {
    treefmt = let
      shellFiles = ["*.bash" "bin/*" "test/*"];
    in {
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
    vale.excludes = [
      "./bin/strict-bash"
      "./test/generate"
      "./test/is-on-path"
    ];
  };

  services.github.settings.repository = {
    private = false;
    topics = ["bash" "development" "nix-flakes"];
  };
}

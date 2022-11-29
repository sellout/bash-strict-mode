{
  outputs = {
    self,
    flake-utils,
    nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      src = pkgs.lib.cleanSource ./.;
    in {
      checks = {
        shellcheck =
          pkgs.runCommand "shellcheck" {
            inherit src;
          } ''
            source $src/strict-mode.bash
            find $src -name '*.bash' -exec \
              ${pkgs.shellcheck}/bin/shellcheck -x {} +
            find $src/test -type f -exec \
              ${pkgs.shellcheck}/bin/shellcheck -x {} +
            mkdir -p $out
          '';
      };

      formatter = pkgs.alejandra;

      packages = {
        default = self.packages.${system}.bash-strict-mode;

        bash-strict-mode = pkgs.stdenv.mkDerivation {
          inherit src;

          name = "bash-strict-mode";

          doCheck = true;

          checkPhase = ''
            source $src/strict-mode.bash
            ${pkgs.bats}/bin/bats $src/test/all-tests.bats
          '';

          # This isn’t executable, but putting it in `bin/` makes it
          # possible for `source` to find it without a path.
          installPhase = ''
            source $src/strict-mode.bash
            mkdir -p $out/bin
            cp $src/strict-mode.bash $out/bin/
          '';

          doInstallCheck = true;

          installCheckPhase = ''
            # should find strict-mode.bash in `PATH`
            $src/test/is-on-path
          '';
        };
      };

      devShells = {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.nodePackages.bash-language-server
          ];
        };
      };
    });
}

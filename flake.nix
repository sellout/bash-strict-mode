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

          nativeBuildInputs = [
            pkgs.bats
          ];

          patchPhase = ''
            runHook prePatch
            patchShebangs ./test
            runHook postPatch
          '';

          doCheck = true;

          checkPhase = ''
            source ./strict-mode.bash
            bats --print-output-on-failure ./test/all-tests.bats
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
            ./test/is-on-path
          '';
        };
      };

      devShells = {
        default = self.packages.${system}.default.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [
            pkgs.nodePackages.bash-language-server
          ];
        });
      };
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:NixOS/nixpkgs/release-22.05";
  };
}

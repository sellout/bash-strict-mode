{
  outputs = { self, flake-utils, nixpkgs}:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        src = pkgs.lib.cleanSource ./.;
      in
        {
          checks = {
            shellcheck = pkgs.runCommand "shellcheck" {
              inherit src;
            } ''
              source $src/strict-mode.bash
              find $src -name '*.bash' -exec \
                ${pkgs.shellcheck}/bin/shellcheck {} \;
              mkdir -p $out
            '';
          };

          packages = {
            default = self.packages.${system}.bash-strict-mode;

            bash-strict-mode = pkgs.stdenv.mkDerivation {
              inherit src;

              name = "bash-strict-mode";

              doCheck = true;

              checkPhase = ''
                source $src/strict-mode.bash
                ${pkgs.bats}/bin/bats $src/test/all-tests.bash
              '';

              installPhase = ''
                source $src/strict-mode.bash
                mkdir -p $out
                cp $src/strict-mode.bash $out/
              '';
            };
          };
        });
}

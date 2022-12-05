{
  outputs = {
    self,
    flake-utils,
    nixpkgs,
    shellcheck-nix-attributes,
  }:
    {
      overlays.default = final: prev: {
        inherit (self.packages.${final.system}) bash-strict-mode;
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      shellchecked = pkgs.callPackage shellcheck-nix-attributes {};

      src = pkgs.lib.cleanSource ./.;
    in {
      packages = {
        default = self.packages.${system}.bash-strict-mode;

        bash-strict-mode = shellchecked (pkgs.stdenv.mkDerivation {
          inherit src;

          pname = "bash-strict-mode";

          version = "0.1.0";

          meta = {
            description = "Making shell scripts more robust.";
            longDescription = ''
              Bash strict mode is a collection of settings to help catch bugs in
              shell scripts. It is intended to be sourced in scripts, not used
              in an interactive shell where some of the behaviors prohibited
              here are desirable.
            '';
          };

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
        });
      };

      # TODO: Add `shellchecked` here after NixOS/nixpkgs#204606 is merged.
      devShells.default = pkgs.mkShell {
        inputsFrom = builtins.attrValues self.packages.${system};

        nativeBuildInputs = [
          pkgs.nodePackages.bash-language-server
        ];
      };

      checks = {
        shellcheck = shellchecked (pkgs.runCommand "shellcheck" {
            inherit src;
          } ''
            source $src/strict-mode.bash
            find $src -name '*.bash' -exec \
              ${pkgs.shellcheck}/bin/shellcheck -x {} +
            find $src/test -type f -exec \
              ${pkgs.shellcheck}/bin/shellcheck -x {} +
            mkdir -p $out
          '');
      };

      formatter = pkgs.alejandra;
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:NixOS/nixpkgs/release-22.05";

    shellcheck-nix-attributes = {
      flake = false;
      url = "github:Fuuzetsu/shellcheck-nix-attributes";
    };
  };
}

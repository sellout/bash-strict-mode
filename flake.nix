{
  outputs = {
    self,
    flake-utils,
    nixpkgs,
    shellcheck-nix-attributes,
  }: let
    ## Uses `strict-bash` instead of `bash` for the derivation builder. This
    ## _should_ work for any derivation, but if you’ve already set a builder
    ## that isn’t a Bash script, it’s unlikely to have any effect.
    strictBuilder = pkgs: path: drv:
      drv.overrideAttrs (old: {
        PATH = "${pkgs.bash}/bin:${pkgs.coreutils}/bin:${old.PATH or ""}";
        args = let
          newArgs =
            (
              if (old.builder or null) == null
              then []
              else ["-e" old.builder]
            )
            ++ (old.args or []);
        in
          ["-e" "${path}/bin/strict-bash"]
          ++ (
            if newArgs == []
            then [./default-builder.sh]
            else newArgs
          );
      });
  in
    {
      overlays.default = final: prev: {
        inherit (self.packages.${final.system}) bash-strict-mode;
      };

      lib = {
        ## Similar to `self.lib.drv`, but also runs shellcheck (provided as a
        ## convenience, since this flake depends on shellcheck-nix-attributes
        ## already).
        checkedDrv = pkgs: drv:
          self.lib.shellchecked pkgs (self.lib.drv pkgs drv);

        ## This takes a derivation and ensures its shell snippets are run in
        ## strict mode.
        drv = pkgs:
          strictBuilder pkgs self.packages.${pkgs.system}.bash-strict-mode;

        ## Runs shellcheck on the snippets in a derivation.
        ##
        ## NB: Provided as a convenience, since shellcheck-nix-attributes
        ##     doesn’t yet have a flake. This will likely go away at some point
        ##     after that changes.
        shellchecked = pkgs: pkgs.callPackage shellcheck-nix-attributes {};
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      src = pkgs.lib.cleanSource ./.;
    in {
      apps = {
        default = self.apps.${system}.strict-bash;

        ## TODO: This line is too long. See kamadorueda/alejandra#368
        strict-bash = "${self.packages.${system}.bash-strict-mode}/bin/strict-bash";
      };

      packages = {
        default = self.packages.${system}.bash-strict-mode;

        ## NB: This can’t use `self.lib.checkedDrv` because that creates a
        ##     cycle. So it uses `strictBuilder` directly, then calls
        ##    `self.lib.shellchecked`.
        bash-strict-mode =
          self.lib.shellchecked pkgs
          (strictBuilder pkgs ./. (pkgs.stdenv.mkDerivation {
            inherit src;

            pname = "bash-strict-mode";
            version = "0.1.0";

            meta = {
              description = "Making shell scripts more robust.";
              longDescription = ''
                Bash strict mode is a collection of settings to help catch bugs
                in shell scripts. It is intended to be sourced in scripts, not
                used in an interactive shell where some of the behaviors
                prohibited here are desirable.
              '';
            };

            nativeBuildInputs = [pkgs.bats];

            patchPhase = ''
              runHook prePatch
              ( # Remove +u (and subshell) once NixOS/nixpkgs#207203 is merged
                set +u
                patchShebangs ./test
              )
              runHook postPatch
            '';

            doCheck = true;

            checkPhase = ''
              runHook preCheck
              bats --print-output-on-failure ./test/all-tests.bats
              ./test/generate strict-mode
              ( # Remove +u (and subshell) once NixOS/nixpkgs#207203 is merged
                set +u
                patchShebangs ./test/strict-mode
              )
              bats --print-output-on-failure ./test/strict-mode/all-tests.bats
              runHook postCheck
            '';

            ## This isn’t executable, but putting it in `bin/` makes it possible
            ## for `source` to find it without a path.
            installPhase = ''
              runHook preInstall
              mkdir -p "$out"
              cp -r ./bin "$out/"
              runHook postInstall
            '';

            doInstallCheck = true;

            installCheckPhase = ''
              runHook preInstallCheck
              ./test/generate strict-bash
              export PATH="$out/bin:$PATH"
              ( # Remove +u (and subshell) once NixOS/nixpkgs#207203 is merged
                set +u
                patchShebangs ./test/strict-bash
              )
              # should find things in `PATH`
              ./test/is-on-path
              bats --print-output-on-failure ./test/strict-bash/all-tests.bats
              runHook postInstallCheck
            '';
          }));
      };

      ## TODO: Add `self.lib.checkedDrv` here after
      ##       https://github.com/NixOS/nixpkgs/commit/58eb3d380601897c6ba9679eafc9c77305549b6f
      ##       makes it into a release.
      devShells.default = self.lib.drv pkgs (pkgs.mkShell {
        inputsFrom =
          builtins.attrValues self.checks.${system}
          ++ builtins.attrValues self.packages.${system};

        nativeBuildInputs = [
          ## Bash language server,
          ## https://github.com/bash-lsp/bash-language-server#readme
          pkgs.nodePackages.bash-language-server
          ## Nix LSP server,
          ## https://github.com/nix-community/rnix-lsp#readme
          pkgs.rnix-lsp
        ];
      });

      checks = {
        shellcheck = self.lib.checkedDrv pkgs (pkgs.runCommand "shellcheck" {
            inherit src;

            nativeBuildInputs = [pkgs.shellcheck];
          } ''
            find $src/bin -type f -exec \
              shellcheck --external-sources --shell bash {} +
            find $src/test -type f -exec \
              shellcheck --external-sources --shell bash {} +
            mkdir -p $out
          '');
      };

      formatter = pkgs.alejandra;
    });

  inputs = {
    flake-utils.url = github:numtide/flake-utils;

    nixpkgs.url = github:NixOS/nixpkgs/release-22.11;

    # lint shell snippets in Nix
    shellcheck-nix-attributes = {
      flake = false;
      url = github:Fuuzetsu/shellcheck-nix-attributes;
    };
  };
}

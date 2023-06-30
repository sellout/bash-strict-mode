{
  description = "Write better shell scripts.";

  nixConfig = {
    ## https://github.com/NixOS/rfcs/blob/master/rfcs/0045-deprecate-url-syntax.md
    extra-experimental-features = ["no-url-literals"];
    extra-substituters = ["https://cache.garnix.io"];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    ## Isolate the build.
    registries = false;
    sandbox = true;
  };

  outputs = inputs: let
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

    supportedSystems = inputs.flake-utils.lib.defaultSystems;
  in
    {
      overlays = {
        default = final: prev: {
          inherit (inputs.self.packages.${final.system}) bash-strict-mode;
        };
      };

      homeConfigurations =
        builtins.listToAttrs
        (builtins.map
          (system: {
            name = "${system}-example";
            value = inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = import inputs.nixpkgs {
                inherit system;
                overlays = [inputs.self.overlays.default];
              };

              modules = [
                ({pkgs, ...}: {
                  home.packages = [pkgs.bash-strict-mode];

                  # These attributes are simply required by home-manager.
                  home = {
                    homeDirectory = /tmp/bash-strict-mode-example;
                    stateVersion = "23.05";
                    username = "bash-strict-mode-example-user";
                  };
                })
              ];
            };
          })
          supportedSystems);

      lib = {
        ## Similar to `inputs.self.lib.drv`, but also runs shellcheck (provided as
        ## a convenience, since this flake depends on shellcheck-nix-attributes
        ## already).
        checkedDrv = pkgs: drv:
          inputs.self.lib.shellchecked pkgs (inputs.self.lib.drv pkgs drv);

        checks = {
          ## A Shellcheck check, see `outputs.checks.${system}.lint` for an
          ## example.
          shellcheck = {
            pkgs,
            src,
            args ? [],
          }:
            inputs.self.lib.checkedDrv pkgs
            (pkgs.runCommand "shellcheck" {
                inherit src;

                nativeBuildInputs = [pkgs.shellcheck];
              } ''
                find "$src" -type f -not -name "*shellcheckrc" -exec \
                  shellcheck \
                  ${inputs.nixpkgs.lib.concatMapStringsSep
                  " "
                  (arg: "\"${arg}\"")
                  args} \
                  {} +
                mkdir -p $out
              '');
        };

        ## This takes a derivation and ensures its shell snippets are run in
        ## strict mode.
        drv = pkgs:
          strictBuilder pkgs inputs.self.packages.${pkgs.system}.bash-strict-mode;

        ## Runs shellcheck on the snippets in a derivation.
        ##
        ## NB: Provided as a convenience, since shellcheck-nix-attributes
        ##     doesn’t yet have a flake. This will likely go away at some point
        ##     after that changes.
        shellchecked = pkgs: pkgs.callPackage inputs.shellcheck-nix-attributes {};
      };
    }
    // inputs.flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import inputs.nixpkgs {inherit system;};

      src = pkgs.lib.cleanSource ./.;
    in {
      apps = {
        default = inputs.self.apps.${system}.strict-bash;

        ## TODO: This line is too long. See kamadorueda/alejandra#368
        strict-bash = "${inputs.self.packages.${system}.bash-strict-mode}/bin/strict-bash";
      };

      packages = {
        default = inputs.self.packages.${system}.bash-strict-mode;

        ## NB: This can’t use `self.lib.checkedDrv` because that creates a
        ##     cycle. So it uses `strictBuilder` directly, then calls
        ##    `self.lib.shellchecked`.
        bash-strict-mode =
          inputs.self.lib.shellchecked pkgs
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

      ## TODO: Use `inputs.self.lib.checkedDrv` here after
      ##       NixOS/nixpkgs#204606 makes it into a release.
      devShells.default = inputs.self.lib.drv pkgs (pkgs.mkShell {
        inputsFrom =
          builtins.attrValues inputs.self.checks.${system}
          ++ builtins.attrValues inputs.self.packages.${system};

        nativeBuildInputs = [
          ## Nix language server, https://github.com/oxalica/nil#readme
          pkgs.nil
          ## Bash language server,
          ## https://github.com/bash-lsp/bash-language-server#readme
          pkgs.nodePackages.bash-language-server
        ];
      });

      checks = {
        lint = inputs.self.lib.checks.shellcheck {
          inherit pkgs;
          args = ["--external-sources"];
          src =
            builtins.filterSource
            (path: type:
              inputs.nixpkgs.lib.hasInfix "/bin" path
              || inputs.nixpkgs.lib.hasInfix "/test" path)
            ./.;
        };

        nix-format = inputs.self.lib.checkedDrv pkgs (pkgs.stdenv.mkDerivation {
          inherit src;

          name = "nix fmt";

          nativeBuildInputs = [inputs.self.formatter.${system}];

          buildPhase = ''
            runHook preBuild
            alejandra --check .
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            runHook preInstall
          '';
        });
      };

      ## Nix code formatter, https://github.com/kamadorueda/alejandra#readme
      formatter = pkgs.alejandra;
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/release-23.05";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";

    ## lint shell snippets in Nix
    shellcheck-nix-attributes = {
      flake = false;
      url = "github:Fuuzetsu/shellcheck-nix-attributes";
    };
  };
}

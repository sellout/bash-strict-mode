{
  description = "Write better shell scripts.";

  nixConfig = {
    ## https://github.com/NixOS/rfcs/blob/master/rfcs/0045-deprecate-url-syntax.md
    extra-experimental-features = ["no-url-literals"];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    extra-trusted-substituters = ["https://cache.garnix.io"];
    ## Isolate the build.
    registries = false;
    sandbox = "relaxed";
  };

  outputs = {
    flake-utils,
    flaky,
    nixpkgs,
    self,
    shellcheck-nix-attributes,
  }: let
    sys = flake-utils.lib.system;

    strictBuilder = command: drv:
      drv.overrideAttrs (old: {
        ## NB: Overriding the builder is complicated.
        ##   • if you override `builder` directly, then the default `args` never
        ##     get set
        ##   • if you overide both `builder` and `args`, then they seem to get
        ##     reset 🤷
        ##
        ##     So, instead we just set the command we want to run as an argument
        ##     to be execed.
        args = [command ./default-builder.bash];

        ## The default `fixupPhase` calls `patchShebangs`, which currently doesn’t
        ## satisfy strict mode. These disable `nounset` for the duration of the
        ## `fixupPhase`.
        preFixup =
          old.preFixup
          or ""
          + ''
            set +u
          '';
        postFixup =
          ''
            set -u
          ''
          + old.postFixup or "";
      });

    supportedSystems = flaky.lib.defaultSystems;
  in
    {
      schemas = {
        inherit
          (flaky.schemas)
          schemas
          overlays
          lib
          packages
          projectConfigurations
          devShells
          checks
          ;
      };

      overlays = {
        default =
          nixpkgs.lib.composeExtensions
          self.overlays.dependencies
          self.overlays.local;

        dependencies = final: prev: {
          haskellPackages = prev.haskellPackages.extend (hfinal: hprev:
            if final.system == sys.i686-linux
            then {
              ## NB: Pandoc currently fails a couple tests on i686 in Nixpkgs
              ##     23.11.
              pandoc_3_1_9 = hprev.pandoc_3_1_9.overrideAttrs (old: {
                doCheck = false;
              });
            }
            else {});
        };

        local = final: prev: {
          inherit (self.packages.${final.system}) bash-strict-mode;
        };
      };

      lib = {
        ## Similar to `self.lib.drv`, but also runs shellcheck (provided
        ## as a convenience, since this flake depends on
        ## shellcheck-nix-attributes already).
        checkedDrv = pkgs: drv:
          self.lib.shellchecked pkgs (self.lib.drv pkgs drv);

        ## This takes a derivation and ensures its shell snippets are run in
        ## strict mode.
        drv = pkgs: strictBuilder self.apps.${pkgs.system}.strict-bash.program;

        ## Runs shellcheck on the snippets in a derivation.
        ##
        ## NB: Provided as a convenience, since shellcheck-nix-attributes
        ##     doesn’t yet have a flake. This will likely go away at some point
        ##     after that changes.
        shellchecked = pkgs:
          pkgs.callPackage shellcheck-nix-attributes {};
      };

      homeConfigurations =
        builtins.listToAttrs
        (builtins.map
          (flaky.lib.homeConfigurations.example self
            [({pkgs, ...}: {home.packages = [pkgs.bash-strict-mode];})])
          supportedSystems);
    }
    // flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.dependencies];
      };

      src = pkgs.lib.cleanSource ./.;
    in {
      apps = {
        default = self.apps.${system}.strict-bash;

        strict-bash = {
          type = "app";
          ## TODO: This line is too long. See kamadorueda/alejandra#368
          program = "${self.packages.${system}.bash-strict-mode}/bin/strict-bash";
        };
      };

      packages = {
        default = self.packages.${system}.bash-strict-mode;

        ## NB: This can’t use `self.lib.checkedDrv` because that creates a
        ##     cycle. So it uses `strictBuilder` directly, then calls
        ##    `self.lib.shellchecked`.
        bash-strict-mode =
          self.lib.shellchecked pkgs
          (strictBuilder "strict-bash" (pkgs.stdenv.mkDerivation {
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

            ## This is needed so that we can run `strict-bash` as our builder
            ## before it’s installed.
            PATH = builtins.concatStringsSep ":" [
              ./bin
              "${pkgs.bash}/bin"
              "${pkgs.coreutils}/bin"
            ];

            nativeBuildInputs = [
              pkgs.bats
              pkgs.makeWrapper
            ];

            patchPhase = ''
              runHook prePatch
              (set +u; patchShebangs ./test)
              runHook postPatch
            '';

            doCheck = true;

            checkPhase = ''
              runHook preCheck
              bats --print-output-on-failure ./test/all-tests.bats
              ./test/generate strict-mode
              (set +u; patchShebangs ./test/strict-mode)
              bats --print-output-on-failure ./test/strict-mode/all-tests.bats
              runHook postCheck
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p "$out"
              cp -r ./bin "$out/"
              wrapProgram "$out/bin/strict-bash" \
                --prefix PATH : ${pkgs.lib.makeBinPath [
                pkgs.bashInteractive
                pkgs.coreutils
              ]}
              runHook postInstall
            '';

            doInstallCheck = true;

            installCheckPhase = ''
              runHook preInstallCheck
              ./test/generate strict-bash
              # should not find things in `PATH`
              if ./test/is-on-path; then exit 124; fi
              export PATH="$out/bin:$PATH"
              # should find things in `PATH`
              ./test/is-on-path
              (set +u; patchShebangs ./test/strict-bash)
              bats --print-output-on-failure ./test/strict-bash/all-tests.bats
              runHook postInstallCheck
            '';
          }));
      };

      projectConfigurations =
        flaky.lib.projectConfigurations.default {inherit pkgs self;};

      devShells =
        self.projectConfigurations.${system}.devShells
        // {
          default =
            self.devShells.${system}.project-manager.overrideAttrs
            (old: {
              inputsFrom =
                old.inputsFrom
                or []
                ++ builtins.attrValues
                self.projectConfigurations.${system}.sandboxedChecks
                ++ builtins.attrValues self.packages.${system};
            });
        };
      checks = self.projectConfigurations.${system}.checks;
      formatter = self.projectConfigurations.${system}.formatter;
    });

  inputs = {
    ## Flaky should generally be the source of truth for its inputs.
    flaky = {
      inputs.bash-strict-mode.follows = "";
      url = "github:sellout/flaky";
    };

    flake-utils.follows = "flaky/flake-utils";
    nixpkgs.follows = "flaky/nixpkgs";

    ## lint shell snippets in Nix
    shellcheck-nix-attributes = {
      flake = false;
      url = "github:Fuuzetsu/shellcheck-nix-attributes";
    };
  };
}

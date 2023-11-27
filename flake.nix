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
    ## To allow _noChroot checks to run.
    sandbox = false;
  };

  outputs = {
    flake-utils,
    flaky,
    nixpkgs,
    self,
    shellcheck-nix-attributes,
  }: let
    ## Uses `strict-bash` instead of `bash` for the derivation builder. This
    ## _should_ work for any derivation, but if you’ve already set a builder
    ## that isn’t a Bash script, it’s unlikely to have any effect.
    strictBuilder = pkgs: path: drv:
      drv.overrideAttrs (old: {
        builder = "{path}/bin/strict-bash";
        args = let
          newArgs =
            (
              if (old.builder or null) == null
              then []
              else ["-e" old.builder]
            )
            ++ (old.args or []);
        in
          if newArgs == []
          then ["${nixpkgs}/pkgs/stdenv/generic/default-builder.sh"]
          else newArgs;
      });

    supportedSystems = flake-utils.lib.defaultSystems;
  in
    {
      schemas = {
        inherit
          (flaky.schemas)
          overlays
          homeConfigurations
          apps
          packages
          devShells
          projectConfigurations
          checks
          formatter
          ;
      };

      overlays.default = final: prev: {
        inherit (self.packages.${final.system}) bash-strict-mode;
      };

      lib = {
        ## Similar to `self.lib.drv`, but also runs shellcheck (provided
        ## as a convenience, since this flake depends on
        ## shellcheck-nix-attributes already).
        checkedDrv = pkgs: drv:
          self.lib.shellchecked pkgs (self.lib.drv pkgs drv);

        ## This takes a derivation and ensures its shell snippets are run in
        ## strict mode.
        drv = pkgs:
          strictBuilder
          pkgs
          self.packages.${pkgs.system}.bash-strict-mode;

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
          (flaky.lib.homeConfigurations.example
            "bash-strict-mode"
            self
            [({pkgs, ...}: {home.packages = [pkgs.bash-strict-mode];})])
          supportedSystems);
    }
    // flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import nixpkgs {inherit system;};

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

            nativeBuildInputs = [
              pkgs.bats
              pkgs.makeWrapper
            ];

            patchPhase = ''
              runHook prePatch
              patchShebangs ./test
              runHook postPatch
            '';

            doCheck = true;

            checkPhase = ''
              runHook preCheck
              bats --print-output-on-failure ./test/all-tests.bats
              ./test/generate strict-mode
              patchShebangs ./test/strict-mode
              bats --print-output-on-failure ./test/strict-mode/all-tests.bats
              runHook postCheck
            '';

            ## This isn’t executable, but putting it in `bin/` makes it possible
            ## for `source` to find it without a path.
            installPhase = ''
              runHook preInstall
              mkdir -p "$out"
              cp -r ./bin "$out/"
              wrapProgram "$out/bin/strict-bash" \
                --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.bashInteractive]}
              runHook postInstall
            '';

            doInstallCheck = true;

            installCheckPhase = ''
              runHook preInstallCheck
              ./test/generate strict-bash
              export PATH="$out/bin:$PATH"
              patchShebangs ./test/strict-bash
              # should find things in `PATH`
              ./test/is-on-path
              bats --print-output-on-failure ./test/strict-bash/all-tests.bats
              runHook postInstallCheck
            '';
          }));
      };

      projectConfigurations = flaky.lib.projectConfigurations.default {
        inherit pkgs self;
      };

      devShells = self.projectConfigurations.${system}.devShells;
      checks = self.projectConfigurations.${system}.checks;
      formatter = self.projectConfigurations.${system}.formatter;
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    flaky = {
      inputs = {
        bash-strict-mode.follows = "";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:sellout/flaky";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";

    ## lint shell snippets in Nix
    shellcheck-nix-attributes = {
      flake = false;
      url = "github:Fuuzetsu/shellcheck-nix-attributes";
    };
  };
}

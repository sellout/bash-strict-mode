{
  flake-utils,
  flaky,
  nixpkgs,
  self,
  shellcheck-nix-attributes,
  systems,
}: let
  supportedSystems = import systems;

  localPkgsLib = pkgs:
    import ../../nix/pkgsLib {
      inherit pkgs shellcheck-nix-attributes;
      inherit (nixpkgs) lib;
    };

  localPackages = pkgs:
    import ../../nix/packages {inherit pkgs shellcheck-nix-attributes;};
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
        formatter
        ;
    };

    overlays = {
      default =
        nixpkgs.lib.composeExtensions
        flaky.overlays.default
        self.overlays.local;

      local = final: prev: localPkgsLib final // localPackages final;
    };

    homeConfigurations =
      builtins.listToAttrs
      (builtins.map
        (flaky.lib.homeConfigurations.example self
          [({pkgs, ...}: {home.packages = [pkgs.bash-strict-mode];})])
        supportedSystems);
  }
  // flake-utils.lib.eachSystem supportedSystems (system: let
    pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
      flaky.overlays.default
    ];
  in {
    apps = {
      default = self.apps.${system}.strict-bash;

      strict-bash = flake-utils.lib.mkApp {
        drv = self.packages.${system}.bash-strict-mode;
      };
    };

    pkgsLib = localPkgsLib pkgs;

    packages =
      {default = self.packages.${system}.bash-strict-mode;}
      // localPackages pkgs;

    projectConfigurations =
      flaky.lib.projectConfigurations.bash {inherit pkgs self;};

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
  })

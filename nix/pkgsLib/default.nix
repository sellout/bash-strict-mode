{
  lib,
  pkgs,
  shellcheck-nix-attributes,
}: let
  stage0 = import ./stage0.nix {inherit pkgs shellcheck-nix-attributes;};

  strictBuilder = import ./strict-builder.nix;

  bash-strict-mode = pkgs.callPackage ../packages/bash-strict-mode.nix {
    inherit strictBuilder;
    inherit (stage0) shellchecked;
  };

  ## This takes a derivation and ensures its shell snippets are run in
  ## strict mode.
  strictDerivation = strictBuilder (lib.getExe bash-strict-mode);
in
  stage0
  // {
    inherit strictDerivation;

    ## Similar to `self.lib.drv`, but also runs shellcheck (provided
    ## as a convenience, since this flake depends on
    ## shellcheck-nix-attributes already).
    checkedDrv = drv: stage0.shellchecked (strictDerivation drv);
  }

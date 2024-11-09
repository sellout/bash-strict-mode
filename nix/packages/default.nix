{
  pkgs,
  shellcheck-nix-attributes,
}: let
  pkgsLib =
    import ../pkgsLib/stage0.nix {inherit pkgs shellcheck-nix-attributes;};

  strictBuilder = import ../pkgsLib/strict-builder.nix;
in {
  bash-strict-mode = pkgs.callPackage ./bash-strict-mode.nix {
    inherit strictBuilder;
    inherit (pkgsLib) shellchecked;
  };
}

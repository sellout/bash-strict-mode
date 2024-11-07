## The subset of `pkgsLib` that doesn’t depend on any local packages.
{
  pkgs,
  shellcheck-nix-attributes,
}: {
  ## Runs shellcheck on the snippets in a derivation.
  ##
  ## NB: Provided as a convenience, since shellcheck-nix-attributes doesn’t yet
  ##     have a flake. This will likely go away at some point after that
  ##     changes.
  shellchecked = pkgs.callPackage shellcheck-nix-attributes {};
}

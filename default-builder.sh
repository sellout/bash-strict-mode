### TODO: This is just a copy of default-builder.sh from
###       github:NixOS/nixpkgs#pkgs/stdenv/generic/default-builder.sh. We
###       shouldn’t have to copy it, but I can’t find it in the store, so I’m at
###       a loss.

source "${stdenv}/setup"
genericBuild

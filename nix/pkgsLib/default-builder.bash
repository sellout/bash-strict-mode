## This is a copy of ${nixpkgs}/pkgs/stdenv/generic/default-builder.sh modified
## to satisfy `strict-bash`. This should be removed once the original passes.

if [[ -v NIX_ATTRS_SH_FILE && -e $NIX_ATTRS_SH_FILE ]]; then
  # shellcheck disable=SC1090
  source "$NIX_ATTRS_SH_FILE"
elif [[ -f .attrs.sh ]]; then
  # shellcheck disable=SC1091
  source .attrs.sh
fi

# shellcheck disable=SC1091,SC2154
source "$stdenv/setup"
genericBuild

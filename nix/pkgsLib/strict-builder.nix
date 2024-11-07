command: drv:
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
})

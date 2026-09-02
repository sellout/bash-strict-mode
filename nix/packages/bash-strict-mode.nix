{
  bash,
  bashInteractive,
  bats,
  coreutils,
  lib,
  makeWrapper,
  shellchecked,
  stdenv,
  strictBuilder,
  ...
}:
## NB: This can’t use `self.lib.checkedDrv` because that creates a cycle. So it
##     uses `strictBuilder` directly, then calls `self.lib.shellchecked`.
shellchecked (strictBuilder "strict-bash" (stdenv.mkDerivation {
  pname = "bash-strict-mode";
  version = "0.1.0";

  src = lib.cleanSource ../..;

  meta = {
    description = "Making shell scripts more robust.";
    longDescription = ''
      Bash strict mode is a collection of settings to help catch bugs
      in shell scripts. It is intended to be sourced in scripts, not
      used in an interactive shell where some of the behaviors
      prohibited here are desirable.
    '';
    mainProgram = "strict-bash";
  };

  ## This is needed so that we can run `strict-bash` as our builder
  ## before it’s installed.
  PATH = builtins.concatStringsSep ":" [
    ../../bin
    "${bash}/bin"
    "${coreutils}/bin"
  ];

  nativeBuildInputs = [
    bats
    makeWrapper
  ];

  patchPhase = ''
    runHook prePatch
    (set +u; patchShebangs ./test)
    runHook postPatch
  '';

  doCheck = true;

  checkPhase = ''
    runHook preCheck
    ## The builder itself runs under strict-bash, so we need to unset these to
    ## run the tests properly.
    env -u BASH_ENV -u SHELLOPTS -u BASHOPTS \
      bats --print-output-on-failure ./test/all-tests.bats
    ./test/generate strict-mode
    (set +u; patchShebangs ./.cache/test/strict-mode)
    env -u BASH_ENV -u SHELLOPTS -u BASHOPTS \
      bats --print-output-on-failure ./.cache/test/strict-mode/all-tests.bats
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r ./bin "$out/"
    wrapProgram "$out/bin/strict-bash" \
      --prefix PATH : ${lib.makeBinPath [
      bashInteractive
      coreutils
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
    ## NOTE: This can’t use `patchShebangs`, because `strict-bash` is a script,
    ##       and (depending on the OS & shell) scripts are rejected as
    ##       interpreters, with misleading fallback behavior. Instead, we make
    ##       Bash the interpreter, and have it call the full path of
    ##       `strict-bash`.
    for t in ./.cache/test/strict-bash/*; do
      if [ -x "$t" ]; then
        sed -i "1s|.*|#!$(command -v bash) $out/bin/strict-bash|" "$t"
      fi
    done
    env -u BASH_ENV -u SHELLOPTS -u BASHOPTS \
      bats --print-output-on-failure ./.cache/test/strict-bash/all-tests.bats
    runHook postInstallCheck
  '';
}))

# Shake&Tune (https://github.com/Frix-x/klippain-shaketune)
# Upstream install symlinks <repo>/shaketune into klippy/extras and pip-installs
# its requirements into the klippy venv. Its GitPython-based version detection
# falls back to 'unknown' in the nix store (wrapped in try/except upstream) —
# cosmetic only.
inputs: pkgs: {
  name = "shaketune";

  # numpy is already in klipper's base env; these are the remaining
  # requirements.txt entries (nixpkgs versions, not upstream's exact pins).
  pythonPackages = ps: with ps; [ matplotlib gitpython zstandard ];

  installExtras = ''
    ln -s ${inputs.klippain-shaketune}/shaketune $out/lib/klipper/extras/shaketune
  '';
}

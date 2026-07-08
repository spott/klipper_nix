# klipper-toolchanger-hard (https://github.com/Contomo/klipper-toolchanger-hard)
# viesturz/klipper-toolchanger fork supporting both Klipper and Kalico.
# Upstream install.sh only symlinks extras (top-level *.py plus package dirs
# with __init__.py); all cfg files under examples/ are manually-copied
# starting points, so this plugin manages no config files. No python deps
# beyond klipper's base env. Conflicts with toolchanger-easy (same extras
# module names) — the module asserts they aren't enabled together.
inputs: pkgs: let
  src = inputs.klipper-toolchanger-hard;
in {
  name = "toolchanger-hard";

  pythonPackages = ps: [ ];

  installExtras = ''
    # -sfn to match upstream install.sh: the plugin's copy overrides extras
    # the base already bundles (kalico ships e.g. tools_calibrate.py).
    for f in ${src}/klipper/extras/*.py; do
      ln -sfn "$f" $out/lib/klipper/extras/$(basename "$f")
    done
    # Package dir; copy instead of symlink to drop the committed __pycache__.
    cp -r --no-preserve=mode ${src}/klipper/extras/kalico_compat $out/lib/klipper/extras/
    rm -rf $out/lib/klipper/extras/kalico_compat/__pycache__
  '';

  # Reference configs (macros.cfg, dock locations, z probe variants, ...);
  # copy what you need into your printer config and edit there.
  examples = "${src}/examples";
}

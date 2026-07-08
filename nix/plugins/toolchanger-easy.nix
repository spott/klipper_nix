# klipper-toolchanger-easy (https://github.com/jwellman80/klipper-toolchanger-easy)
# Mirrors upstream install.sh:
#   - klipper/extras/*.py         → klippy/extras (symlinked)
#   - shared + probe-type macros  → config/toolchanger/readonly-configs (symlinked)
#   - user-editable examples      → config/toolchanger{,/tools} (cp -n, never overwritten)
# requirements.txt is numpy only, which klipper's base env already has.
inputs: pkgs: let
  src = inputs.klipper-toolchanger-easy;
  easy = "${src}/examples/easy-additions";
in {
  name = "toolchanger-easy";

  pythonPackages = ps: [ ];

  installExtras = ''
    for f in ${src}/klipper/extras/*.py; do
      ln -s "$f" $out/lib/klipper/extras/
    done
  '';

  # Read-only macro bundle, linked into the config dir as a store symlink.
  # printer.cfg includes e.g. [include toolchanger/readonly-configs/toolchanger.cfg].
  # Upstream links toolchanger-include{,_scanner}.cfg into readonly-configs
  # under the fixed name toolchanger-include.cfg depending on probe type.
  readonlyConfigsFor = probeType:
    pkgs.runCommand "toolchanger-easy-readonly-configs" { } (''
      mkdir -p $out
      for f in toolchanger homing calibrate-offsets toolchanger-macros crash-detection; do
        ln -s ${easy}/$f.cfg $out/$f.cfg
      done
    ''
    + (if probeType == "tap_per_tool" then ''
      ln -s ${easy}/tool_detection.cfg $out/tool_detection.cfg
      ln -s ${easy}/user-configs/toolchanger-include.cfg $out/toolchanger-include.cfg
    '' else ''
      ln -s ${easy}/user-configs/toolchanger-include_scanner.cfg $out/toolchanger-include.cfg
    ''));

  # User-editable starting points; the module copies these once and never
  # overwrites them (upstream uses cp -n).
  userConfigsFor = probeType:
    pkgs.runCommand "toolchanger-easy-user-configs" { } ''
      mkdir -p $out/tools
      cp ${easy}/user-configs/toolchanger-config.cfg $out/
      cp ${easy}/user-configs/tools/${probeType}/* $out/tools/
    '';
}

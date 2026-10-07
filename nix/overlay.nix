# Overrides nixpkgs' klipper to build from the flake's upstream sources
# (upstream Klipper and the Kalico fork share the same layout, so one
# mkHost covers both) and adds a `withPlugins` passthru that composes
# klippy extras + their python deps into a single package. Extras must
# live inside $out/lib/klipper/extras (klippy discovers them relative to
# its own path) and plugin python deps must be in the same withPackages
# env — so no symlinkJoin.
inputs: final: prev: let
  inherit (final) lib;

  plugins = import ./plugins inputs final;

  mkHost = { pname, src, version, basePythonPackages ? ps: [ ] }: let
    mk = selected:
      (prev.klipper.override {
        extraPythonPackages = ps:
          basePythonPackages ps
          ++ lib.concatMap (p: p.pythonPackages ps) selected;
      }).overrideAttrs (old: {
        inherit pname version src;
        # Flake inputs unpack as "source"; the inherited value hardcodes the
        # fetchFromGitHub source name.
        sourceRoot = "source/klippy";
        # nixpkgs' postPatch hard-fails on files that moved upstream
        # (kalico removed klippy/console.py); guard existence and tolerate
        # already-fixed shebangs.
        postPatch = ''
          for file in klippy.py console.py parsedump.py; do
            if [ -e "$file" ]; then
              substituteInPlace "$file" \
                --replace-quiet '/usr/bin/env python2' '/usr/bin/env python'
            fi
          done

          # needed for cross compilation
          substituteInPlace ./chelper/__init__.py \
            --replace-fail 'GCC_CMD = "gcc"' 'GCC_CMD = "${final.stdenv.cc.targetPrefix}cc"'

          # Kalico adds -march=native to the chelper build, which would bake
          # the build machine's ISA into a portable store path (built on an
          # Apple-Silicon builder VM, run on a Pi 4 — SIGILL bait). Neutralize;
          # no-op for upstream klipper, which has no NATIVE_FLAGS.
          substituteInPlace ./chelper/__init__.py \
            --replace-quiet 'NATIVE_FLAGS = "-march=native -mtune=native"' 'NATIVE_FLAGS = ""'
        '';
        postInstall =
          (old.postInstall or "")
          # installPhase bakes the old nixpkgs version into .version via rec
          # interpolation; overwrite it so klippy reports the real source rev.
          + ''
            echo "${version}" > $out/lib/klipper/.version
          ''
          + lib.concatMapStrings (p: p.installExtras) selected
          # Kalico's restructured klippy imports the `klippy` package tree at
          # lib/klippy, but nixpkgs installs only a pristine source copy there
          # (for moonraker) — no prebuilt chelper, no plugin extras, no
          # .version. Rather than patching artifacts across one at a time,
          # replace it with a full mirror of the built lib/klipper tree so
          # both entry styles see the same complete installation. Must run
          # after installExtras so plugin symlinks are mirrored too.
          + ''
            chmod -R u+w "$out/lib/klippy"
            rm -rf "$out/lib/klippy"
            cp -a "$out/lib/klipper" "$out/lib/klippy"
          '';
        passthru = (old.passthru or { }) // {
          inherit plugins;
          withPlugins = f: let
            # Dedupe by plugin name (attrsets with functions can't be compared).
            byName = lib.listToAttrs (map (p: lib.nameValuePair p.name p) (selected ++ f plugins));
          in
            mk (lib.attrValues byName);
        };
      });
  in
    mk [ ];

  # Cosmetic (shown by klippy and the web UI) — keep in sync with the kalico
  # input tag in flake.nix. The -g<rev> suffix is always truthful regardless.
  kalicoTag = "v2026.10.00";
in {
  klipper = mkHost {
    pname = "klipper";
    src = inputs.klipper;
    version = "0.13.0-unstable-${builtins.substring 0 8 (inputs.klipper.lastModifiedDate or "00000000")}-g${inputs.klipper.shortRev or "unknown"}";
    # msgspec is in upstream's klippy-requirements.txt but missing from
    # the nixpkgs derivation (optional, used by webhooks.py).
    basePythonPackages = ps: [ ps.msgspec ];
  };

  kalico = mkHost {
    pname = "kalico";
    src = inputs.kalico;
    version = "${kalicoTag}-g${inputs.kalico.shortRev or "unknown"}";
    # kalico <= v2026.07 needed setuptools (python-can < 4.3 on python >=
    # 3.12); v2026.08+ moved to python-can 4.6 and dropped it. Kept because
    # it is harmless and nixpkgs' python-can may still import pkg_resources.
    basePythonPackages = ps: [ ps.setuptools ];
  };
}

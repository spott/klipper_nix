# Overrides nixpkgs' klipper to build from the flake's upstream source and
# adds a `withPlugins` passthru that composes klippy extras + their python
# deps into a single package (extras must live inside $out/lib/klipper/extras
# because klippy discovers them relative to its own path, and plugin python
# deps must be in the same withPackages env — so no symlinkJoin).
inputs: final: prev: let
  inherit (final) lib;

  version = "0.13.0-unstable-${builtins.substring 0 8 (inputs.klipper.lastModifiedDate or "00000000")}-g${inputs.klipper.shortRev or "unknown"}";

  plugins = import ./plugins inputs final;

  mkKlipper = selected:
    (prev.klipper.override {
      extraPythonPackages = ps:
        # msgspec is in upstream's klippy-requirements.txt but missing from
        # the nixpkgs derivation (optional, used by webhooks.py).
        [ ps.msgspec ]
        ++ lib.concatMap (p: p.pythonPackages ps) selected;
    }).overrideAttrs (old: {
      inherit version;
      src = inputs.klipper;
      # Flake inputs unpack as "source"; the inherited value hardcodes the
      # fetchFromGitHub source name.
      sourceRoot = "source/klippy";
      postInstall =
        (old.postInstall or "")
        # installPhase bakes the old nixpkgs version into .version via rec
        # interpolation; overwrite it so klippy reports the real source rev.
        + ''
          echo "${version}" > $out/lib/klipper/.version
        ''
        + lib.concatMapStrings (p: p.installExtras) selected;
      passthru = (old.passthru or { }) // {
        inherit plugins;
        withPlugins = f: let
          # Dedupe by plugin name (attrsets with functions can't be compared).
          byName = lib.listToAttrs (map (p: lib.nameValuePair p.name p) (selected ++ f plugins));
        in
          mkKlipper (lib.attrValues byName);
      };
    });
in {
  klipper = mkKlipper [ ];
}

# Plugin registry. Each plugin is an attrset:
#   name            — attr key, used for dedup in withPlugins
#   pythonPackages  — ps: [...] merged into klippy's python env
#   installExtras   — shell appended to klipper's postInstall; must place
#                     extras inside $out/lib/klipper/extras
# plus optional plugin-specific attrs consumed by the NixOS module.
inputs: pkgs: {
  shaketune = import ./shaketune.nix inputs pkgs;
  toolchanger-easy = import ./toolchanger-easy.nix inputs pkgs;
}

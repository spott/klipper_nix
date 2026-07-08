# klipper_nix

Upstream [Klipper](https://github.com/Klipper3d/klipper) plus declaratively-managed
plugins ([Shake&Tune](https://github.com/Frix-x/klippain-shaketune),
[klipper-toolchanger-easy](https://github.com/jwellman80/klipper-toolchanger-easy))
as a Nix flake, decoupled from nixpkgs' klipper version.

The flake reuses nixpkgs' klipper *derivation* and NixOS *module* — it only swaps
the source (via a flake input tracking upstream master) and layers plugins on top.
Because the stock `services.klipper` module builds firmware, genconf, and flash
scripts from `services.klipper.package`, host klippy and MCU firmware always build
from the same commit.

## Outputs

- `overlays.default` — `klipper` built from the flake's source, with a
  `klipper.withPlugins (p: [ p.shaketune p.toolchanger-easy ])` passthru.
- `nixosModules.default` — applies the overlay and adds:
  - `services.klipper.plugins.shaketune.enable` (+ `resultsDir`)
  - `services.klipper.plugins.toolchanger-easy.enable` (+ `probeType`:
    `tap_per_tool` or `probe_on_shuttle`)
- `packages.{klipper,klipper-shaketune,klipper-full}` for
  `x86_64-linux` / `aarch64-linux`.
- `devShells.default` — `klipper-genconf` for the menuconfig workflow.

## Consuming (NixOS)

```nix
inputs.klipper-flake = {
  url = "github:spott/klipper_nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import `klipper-flake.nixosModules.default` on the printer node, then:

```nix
services.klipper.plugins.shaketune.enable = true;
```

Plugin extras ship inside the klipper package; toolchanger-easy's read-only
macros appear at `<configDir>/toolchanger/readonly-configs` (store symlink,
updates with deploys) and its user-editable examples are copied once into
`<configDir>/toolchanger{,/tools}` and never overwritten. Include from
printer.cfg, e.g.:

```
[include toolchanger/readonly-configs/toolchanger.cfg]
[include toolchanger/toolchanger-config.cfg]
```

Moonraker's `update_manager` plays no role: klipper and plugins are read-only
store paths, and nix is the single update path.

## Updating

```sh
nix flake update klipper                   # klipper → latest upstream master
nix flake update klipper-toolchanger-easy  # → latest main (untagged upstream)
# shaketune: edit the tag in flake.nix's input URL, then:
nix flake update klippain-shaketune
```

Commit/push, then in the consuming repo `nix flake update klipper-flake`,
build, deploy. Rollback = revert the flake.lock change and redeploy.

**On klipper bumps:**

- Reflash MCUs if klippy reports a protocol mismatch after deploy (it refuses
  to run and says so loudly). The `klipper-flash-<mcu>` scripts from
  `services.klipper.firmwares.<mcu>.enableKlipperFlash` are on the printer.
- If the firmware build fails at deploy time, upstream changed Kconfig options
  and the checked-in `.config` is stale — regenerate it (below). Failing at
  build rather than on the printer is the point.
- If klippy fails on a missing python module, upstream grew a dependency:
  diff `scripts/klippy-requirements.txt` against the deps in
  `nix/overlay.nix` + nixpkgs' klipper derivation.

## Regenerating firmware configs (menuconfig)

On a linux machine (or one of the printers):

```sh
nix develop github:spott/klipper_nix
klipper-genconf   # runs make menuconfig against the flake's klipper source
```

Copy the resulting `.config` into the consuming repo next to the printer
(e.g. `3d_printers/<node>/firmware-<mcu>.cfg`) — firmware configs are plain
checked-in text, so firmware builds stay pure.

## Notes

- Plugin python deps come from nixpkgs, not upstream's exact pins
  (e.g. Shake&Tune pins matplotlib 3.9.4; nixpkgs 25.11 ships newer). This has
  been fine in practice.
- Shake&Tune prints `version: unknown` (its GitPython version detection can't
  run in the store); cosmetic.
- toolchanger-easy is untagged upstream and its `examples/easy-additions/`
  layout may move; all paths live in `nix/plugins/toolchanger-easy.nix`.

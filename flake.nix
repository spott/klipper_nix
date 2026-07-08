{
  description = "Upstream Klipper and Kalico with declarative plugins (Shake&Tune, klipper-toolchanger-easy/-hard)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Klipper host software, tracking upstream master. `nix flake update klipper` to bump.
    klipper = {
      url = "github:Klipper3d/klipper";
      flake = false;
    };

    # Shake&Tune is pinned to a release tag; bump deliberately by editing the ref.
    klippain-shaketune = {
      url = "github:Frix-x/klippain-shaketune/v6.0.0";
      flake = false;
    };

    # No release tags upstream; flake.lock pins a main commit.
    klipper-toolchanger-easy = {
      url = "github:jwellman80/klipper-toolchanger-easy";
      flake = false;
    };

    # Kalico (Klipper fork) pinned to its monthly release tag; bump
    # deliberately by editing the ref (and kalicoTag in nix/overlay.nix).
    kalico = {
      url = "github:KalicoCrew/kalico/v2026.07.00";
      flake = false;
    };

    # No release tags upstream; flake.lock pins a main commit.
    klipper-toolchanger-hard = {
      url = "github:Contomo/klipper-toolchanger-hard";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    # klipper is linux-only (meta.platforms), so no darwin outputs.
    systems = [ "x86_64-linux" "aarch64-linux" ];
    forAll = f:
      nixpkgs.lib.genAttrs systems (system:
        f (import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        }));
  in {
    overlays.default = import ./nix/overlay.nix inputs;

    # Importing this module applies the overlay and adds
    # services.klipper.plugins.* options.
    nixosModules.default = import ./nix/module.nix inputs;

    packages = forAll (pkgs: {
      default = pkgs.klipper;
      inherit (pkgs) klipper kalico;
      klipper-shaketune = pkgs.klipper.withPlugins (p: [ p.shaketune ]);
      klipper-full = pkgs.klipper.withPlugins (p: [ p.shaketune p.toolchanger-easy ]);
      kalico-full = pkgs.kalico.withPlugins (p: [ p.shaketune p.toolchanger-hard ]);
    });

    # menuconfig workflow for regenerating firmware .config files:
    #   nix develop github:spott/klipper_nix  (on a linux machine)
    #   klipper-genconf
    devShells = forAll (pkgs: {
      default = pkgs.mkShell {
        packages = [ pkgs.klipper-genconf ];
      };
    });

    checks = nixpkgs.lib.genAttrs systems (system: {
      inherit (self.packages.${system}) klipper klipper-full kalico-full;
    });
  };
}

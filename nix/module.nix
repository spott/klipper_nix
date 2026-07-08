# NixOS module: applies the overlay and adds services.klipper.plugins.*
# options on top of the stock nixpkgs services.klipper module.
inputs: { config, lib, pkgs, ... }: let
  cfg = config.services.klipper;
  pcfg = cfg.plugins;

  enabledPlugins = p:
    lib.optional pcfg.shaketune.enable p.shaketune
    ++ lib.optional pcfg.toolchanger-easy.enable p.toolchanger-easy
    ++ lib.optional pcfg.toolchanger-hard.enable p.toolchanger-hard;

  basePackage = if cfg.flavor == "kalico" then pkgs.kalico else pkgs.klipper;

  toolchanger = pkgs.klipper.plugins.toolchanger-easy;
  toolchangerDir = "${cfg.configDir}/toolchanger";
in {
  options.services.klipper.flavor = lib.mkOption {
    type = lib.types.enum [ "klipper" "kalico" ];
    default = "klipper";
    description = ''
      Host software to run: upstream Klipper or the Kalico fork. Firmware
      built via services.klipper.firmwares follows automatically, so MCUs
      must be reflashed when switching flavor.
    '';
  };

  options.services.klipper.plugins = {
    shaketune = {
      enable = lib.mkEnableOption "Shake&Tune input shaper analysis plugin";
      resultsDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.configDir}/ShakeTune_results";
        defaultText = lib.literalExpression ''"''${config.services.klipper.configDir}/ShakeTune_results"'';
        description = "Directory Shake&Tune writes graphs to (created via tmpfiles).";
      };
    };

    toolchanger-easy = {
      enable = lib.mkEnableOption "klipper-toolchanger-easy (StealthChanger-style toolchanger support)";
      probeType = lib.mkOption {
        type = lib.types.enum [ "tap_per_tool" "probe_on_shuttle" ];
        default = "tap_per_tool";
        description = ''
          Z probe arrangement, mirroring upstream install.sh's prompt:
          TAP sensor on each tool, or a shuttle-mounted Beacon/Cartographer/Eddy.
        '';
      };
    };

    # Extras only (matching upstream install.sh); config starting points live
    # in the repo's examples/ — copy into your printer config and edit there.
    toolchanger-hard.enable =
      lib.mkEnableOption "klipper-toolchanger-hard (Contomo's klipper-toolchanger fork, Klipper+Kalico compatible)";
  };

  config = lib.mkMerge [
    { nixpkgs.overlays = [ (import ./overlay.nix inputs) ]; }

    (lib.mkIf cfg.enable {
      services.klipper.package = lib.mkDefault (basePackage.withPlugins enabledPlugins);

      assertions = [
        {
          assertion = (pcfg.shaketune.enable || pcfg.toolchanger-easy.enable) -> (cfg.user != null && cfg.group != null);
          message = "services.klipper.plugins.* need services.klipper.user/group set (tmpfiles rules need a concrete owner).";
        }
        {
          assertion = pcfg.toolchanger-easy.enable -> cfg.mutableConfig;
          message = "toolchanger-easy delivers user-editable configs into configDir and needs services.klipper.mutableConfig = true.";
        }
        {
          assertion = !(pcfg.toolchanger-easy.enable && pcfg.toolchanger-hard.enable);
          message = "toolchanger-easy and toolchanger-hard ship the same extras module names and cannot be enabled together.";
        }
      ];
    })

    (lib.mkIf (cfg.enable && pcfg.shaketune.enable) {
      systemd.tmpfiles.rules = [
        "d ${pcfg.shaketune.resultsDir} 0775 ${cfg.user} ${cfg.group} - -"
      ];
    })

    (lib.mkIf (cfg.enable && pcfg.toolchanger-easy.enable) {
      systemd.tmpfiles.rules = [
        "d ${toolchangerDir} 0775 ${cfg.user} ${cfg.group} - -"
        "d ${toolchangerDir}/tools 0775 ${cfg.user} ${cfg.group} - -"
        "L+ ${toolchangerDir}/readonly-configs - - - - ${toolchanger.readonlyConfigsFor pcfg.toolchanger-easy.probeType}"
      ];

      # Copy-once for user-editable configs (upstream cp -n semantics); edits
      # and deletions on the printer are never clobbered.
      systemd.services.klipper.preStart = let
        userConfigs = toolchanger.userConfigsFor pcfg.toolchanger-easy.probeType;
      in
        lib.mkAfter ''
          [ -e ${toolchangerDir}/toolchanger-config.cfg ] || \
            cp --no-preserve=mode ${userConfigs}/toolchanger-config.cfg ${toolchangerDir}/
          for f in ${userConfigs}/tools/*; do
            dest=${toolchangerDir}/tools/$(basename "$f")
            [ -e "$dest" ] || cp --no-preserve=mode "$f" "$dest"
          done
        '';
    })
  ];
}

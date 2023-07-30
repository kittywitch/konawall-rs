{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.konawall;
  service = config.systemd.user.services.konawall;
  inherit (config.systemd.user) systemctlPath;
  konashow = pkgs.writeShellScriptBin "konashow" ''
    ${builtins.dirOf systemctlPath}/journalctl \
      _SYSTEMD_INVOCATION_ID=$(${systemctlPath} show -p InvocationID --value konawall.service --user) \
      -o cat --no-pager
  '';
in
  with lib; {
    options.services.konawall = {
      enable = mkEnableOption "enable konawall";
      mode = mkOption {
        type = types.enum ["random" "shuffle" "map"];
        default = "random";
      };
      commonTags = mkOption {
        type = types.listOf types.str;
        default = ["score:>=200" "width:>=1600"];
      };
      tags = mkOption {
        type = types.listOf types.str;
        default = ["nobody"];
      };
      tagList = mkOption {
        type = with types; listOf (listOf str);
        default = singleton cfg.tags;
      };
      package = mkOption {
        type = types.package;
        default = pkgs.konawall;
      };
      konashow = mkOption {
        type = types.package;
        default = konashow;
      };
      interval = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "20m";
        description = "How often to rotate backgrounds (specify as a systemd interval)";
      };
      interval_macos = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 3600;
        description = "How often to rotate backgrounds (specify as int of seconds)";
      };
    };

    config = {
      launchd.agents = mkIf (cfg.enable && pkgs.hostPlatform.isDarwin) {
        konawall = {
          enable = cfg.enable;
          config = {
            Program = "${cfg.package}/bin/konawall";
            ProgramArguments = [
              "--mode"
              cfg.mode
              "--common"
              (concatStringsSep "," cfg.commonTags)
              (concatStringsSep "," cfg.tags)
            ];
            RunAtLoad = true;
            KeepAlive = false;
            StartInterval = cfg.interval_macos;
          };
        };
      };
      systemd.user = mkIf (cfg.enable && pkgs.hostPlatform.isLinux) {
        services = {
          konawall = {
            Unit = rec {
              Description = "Random wallpapers";
              Wants = [
                "network-online.target"
              ];
              After = mkMerge [
                ["graphical-session-pre.target" "network-online.target"]
                (mkIf config.wayland.windowManager.sway.enable ["sway-session.target"])
              ];
              PartOf = mkMerge [
                ["graphical-session.target"]
                (mkIf config.wayland.windowManager.sway.enable ["sway-session.target"])
              ];
              Requisite = PartOf;
            };
            Service = {
              Type = "oneshot";
              Environment = mkIf config.xsession.enable [
                "PATH=${makeBinPath (with pkgs; [feh pkgs.xorg.xsetroot])}"
              ];
              ExecStart = let
                tags = map (concatStringsSep ",") cfg.tagList;
                tags-escaped = escapeShellArgs tags;
                common = concatStringsSep "," cfg.commonTags;
                common-escaped = escapeShellArg common;
              in "${cfg.package}/bin/konawall --mode ${cfg.mode} ${optionalString (cfg.commonTags != []) "--common ${common-escaped}"} ${tags-escaped}";
              RemainAfterExit = true;
              IOSchedulingClass = "idle";
              TimeoutStartSec = "5m";
            };
            Install.WantedBy = mkIf (cfg.interval == null) (mkMerge [
              (mkDefault ["graphical-session.target"])
              (mkIf config.wayland.windowManager.sway.enable ["sway-session.target"])
            ]);
          };
          konawall-rotation = mkIf (cfg.interval != null) {
            Unit = {
              Description = "Random wallpaper rotation";
              inherit (service.Unit) Requisite;
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${systemctlPath} --user --no-block restart konawall";
            };
          };
        };
        timers.konawall-rotation = mkIf (cfg.interval != null) {
          Unit = {
            inherit (service.Unit) After PartOf;
          };
          Timer = {
            OnUnitInactiveSec = cfg.interval;
            OnStartupSec = 0;
          };
          Install.WantedBy = mkMerge [
            (mkDefault ["graphical-session.target"])
            (mkIf config.wayland.windowManager.sway.enable ["sway-session.target"])
          ];
        };
      };
    };
  }

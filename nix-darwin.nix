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
        type = types.nullOr types.int;
        default = null;
        example = 3600;
        description = "How often to rotate backgrounds (specify as a duration in seconds)";
      };
    };
    config.launchd.agents.konawall = mkIf cfg.enable {
      serviceConfig = {
        program = "${cfg.package}/bin/konawall";
        arguments = [
          "--mode"
          cfg.mode
          "--common"
          (concatStringsSep "," cfg.commonTags)
          "--tags"
          (concatStringsSep "," cfg.tags)
        ];
        StartInterval = cfg.interval or 3600;
        keepAlive = false;
        runAtLoad = true;
        standardOutPath = "/tmp/konawall.log";
        standardErrorPath = "/tmp/konawall.log";
      };
    };
  }

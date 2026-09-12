{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.miniM8s;
  wifi = cfg.wifi;
in
{
  options.hardware.miniM8s.wifi = {
    enable = lib.mkEnableOption "the tested Mini M8S wpa_supplicant service";
    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/mini-m8s/wpa_supplicant.conf";
      description = "Absolute path to a root-only runtime wpa_supplicant configuration; keep credentials outside the Nix store.";
    };
  };
  config = lib.mkIf (cfg.enable && wifi.enable) {
    assertions = [
      {
        assertion = lib.hasPrefix "/" wifi.configFile && !(lib.hasPrefix "/nix/store/" wifi.configFile);
        message = "Mini M8S Wi-Fi configFile must be an absolute runtime path outside the Nix store.";
      }
      {
        assertion = !config.networking.wireless.enable && !config.networking.networkmanager.enable;
        message = "Use one Wi-Fi manager: disable the Mini M8S Wi-Fi service when enabling networking.wireless or NetworkManager.";
      }
    ];
    environment.systemPackages = [
      pkgs.wpa_supplicant
      pkgs.iw
    ];
    networking.useDHCP = lib.mkDefault true;
    systemd.tmpfiles.rules = [ "d /run/wpa_supplicant/client 0700 root root -" ];
    systemd.services.mini-m8s-wireless = {
      description = "Mini M8S Wi-Fi connection";
      wantedBy = [ "multi-user.target" ];
      requires = [ "sys-subsystem-net-devices-wlan0.device" ];
      after = [ "sys-subsystem-net-devices-wlan0.device" ];
      before = [ "network.target" ];
      unitConfig.ConditionPathExists = wifi.configFile;
      preStart = ''
        m8s_config=${lib.escapeShellArg wifi.configFile}
        if test "$(${pkgs.coreutils}/bin/stat -Lc %u "$m8s_config")" != 0; then
          echo 'Mini M8S Wi-Fi configuration must be owned by root.' >&2
          exit 1
        fi
        case "$(${pkgs.coreutils}/bin/stat -Lc %a "$m8s_config")" in
          400|600) ;;
          *) echo 'Mini M8S Wi-Fi configuration must have mode 0400 or 0600.' >&2; exit 1 ;;
        esac
      '';
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${pkgs.wpa_supplicant}/bin/wpa_supplicant"
          "-D"
          "nl80211"
          "-i"
          "wlan0"
          "-c"
          wifi.configFile
        ];
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}

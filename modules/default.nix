{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.miniM8s;
in
{
  imports = [ ./wifi.nix ];
  options.hardware.miniM8s = {
    enable = lib.mkEnableOption "experimental original Mini M8S (S905/GXBB, 2 GiB) SD support";
    singleCore = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Keep the single-core configuration used in the successful boot tests.";
    };
    verboseBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Retain the EFI and console diagnostics used during hardware bring-up.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "aarch64-linux";
        message = "Mini M8S support requires an aarch64-linux target.";
      }
    ];
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
    boot.loader.grub.enable = lib.mkDefault false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;
    boot.loader.generic-extlinux-compatible.configurationLimit = lib.mkDefault 3;
    boot.kernelParams = [
      "console=ttyAML0,115200n8"
      "console=tty0"
      "earlycon=efifb,ram"
    ]
    ++ lib.optional cfg.singleCore "maxcpus=1"
    ++ lib.optionals cfg.verboseBoot [
      "fbcon=nodefer"
      "initcall_debug"
      "keep_bootcon"
      "efi=debug"
    ];
    boot.consoleLogLevel = lib.mkDefault (if cfg.verboseBoot then 7 else 4);
    boot.supportedFilesystems = [
      "ext4"
      "vfat"
    ];
    boot.initrd.systemd.enable = lib.mkDefault true;
    boot.initrd.includeDefaultModules = lib.mkDefault false;
    boot.initrd.availableKernelModules = [
      "meson_gx_mmc"
      "mmc_block"
      "ext4"
      "dwc2"
      "phy_meson8b_usb2"
      "usbhid"
      "hid_generic"
    ];
    boot.kernelModules = [
      "meson_drm"
      "pwm_meson"
      "r8723bs"
    ];
    hardware.enableAllHardware = lib.mkDefault false;
    hardware.deviceTree = {
      enable = true;
      name = "amlogic/meson-gxbb-mini-m8s-sd-only.dtb";
      dtbSource = import ../packages/linux-dtbs.nix {
        inherit pkgs;
        kernel = config.boot.kernelPackages.kernel;
      };
    };
    hardware.firmware = [ (import ../packages/firmware.nix { inherit pkgs; }) ];
    hardware.wirelessRegulatoryDatabase = true;
  };
}

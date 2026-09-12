{ ... }: {
  hardware.miniM8s.enable = true;
  hardware.miniM8s.wifi.enable = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/M8S_NIXOS";
    fsType = "ext4";
  };
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/M8S_BOOT";
    fsType = "vfat";
    options = [
      "noauto"
      "ro"
    ];
  };
  system.stateVersion = "26.05";
}

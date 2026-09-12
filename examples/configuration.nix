# Import this alongside nixosModules.default from your own flake.
{ ... }: {
  hardware.miniM8s.enable = true;
  hardware.miniM8s.wifi = {
    enable = true;
    configFile = "/var/lib/mini-m8s/wpa_supplicant.conf";
  };
  networking.hostName = "mini-m8s";
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
  # Identity and access belong to the consuming configuration. Add your key
  # before using this example; no account can SSH in with an empty key list.
  users.users.operator = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [ ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "operator" ];
    };
  };
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  system.stateVersion = "26.05";
}

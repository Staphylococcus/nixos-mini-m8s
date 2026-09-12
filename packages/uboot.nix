{ pkgs, src }:
let
  target =
    if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then
      pkgs
    else
      pkgs.pkgsCross.aarch64-multiplatform;
  overlay = builtins.path {
    path = ../uboot/mini-m8s.dtsi;
    name = "mini-m8s.dtsi";
  };
in
target.buildUBoot {
  version = "2026.07";
  inherit src;
  defconfig = "p201_defconfig";
  filesToInstall = [
    "u-boot.bin"
    "u-boot.dtb"
    ".config"
  ];
  extraConfig = builtins.readFile ../uboot/mini-m8s.config;
  postPatch = ''
    patchShebangs tools scripts
    cat ${overlay} >> arch/arm/dts/meson-gxbb-p201-u-boot.dtsi
  '';
  postConfigure = "make olddefconfig";
  postBuild = ''
    for option in ENV_IS_NOWHERE EFI_VARIABLE_NO_STORE CMD_BOOTEFI EFI_LOAD_FILE2_INITRD CMD_SOURCE VIDEO_MESON USB_KEYBOARD PHY MESON_GXBB_USB_PHY SYS_CONSOLE_IS_IN_ENV; do
      grep -qx "CONFIG_$option=y" .config
    done
    grep -qx 'CONFIG_TEXT_BASE=0x01000000' .config
    grep -qx '# CONFIG_MMC_WRITE is not set' .config
    grep -qx '# CONFIG_CMD_SAVEENV is not set' .config
    ! grep -q '^CONFIG_ENV_IS_IN_.*=y' .config
    test "$(${pkgs.dtc}/bin/fdtget u-boot.dtb /soc/apb@d0000000/mmc@74000 status)" = disabled
    test "$(${pkgs.dtc}/bin/fdtget u-boot.dtb /soc/apb@d0000000/mmc@70000 status)" = disabled
    test "$(${pkgs.dtc}/bin/fdtget u-boot.dtb /soc/apb@d0000000/mmc@72000 status)" = okay
  '';
}

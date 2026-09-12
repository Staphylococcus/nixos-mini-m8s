{ pkgs, uboot }:
let
  launcher = builtins.path {
    path = ../boot/launcher.cmd;
    name = "mini-m8s-launcher.cmd";
  };
in
pkgs.runCommand "mini-m8s-bootloader-files" { nativeBuildInputs = [ pkgs.ubootTools ]; } ''
  mkdir -p $out
  cp ${uboot}/u-boot.bin $out/u-boot.ext
  cp ${uboot}/u-boot.dtb $out/u-boot.dtb
  cp ${launcher} $out/aml_autoscript.cmd
  SOURCE_DATE_EPOCH=0 mkimage -A arm -O linux -T script -C none \
    -n 'Mini M8S RAM-only chainload' -d $out/aml_autoscript.cmd $out/aml_autoscript
  cp $out/aml_autoscript $out/s905_autoscript
  cp $out/aml_autoscript.cmd $out/s905_autoscript.cmd
  cd $out
  sha256sum u-boot.ext aml_autoscript s905_autoscript > SHA256SUMS
''

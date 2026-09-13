{ pkgs }:
# Obtain the blob through nixpkgs and include its redistribution notice.
# Do not vendor Realtek firmware into this repository.
pkgs.runCommand "mini-m8s-rtl8723bs-firmware" { } ''
  install -Dm444 ${pkgs.linux-firmware}/lib/firmware/rtlwifi/rtl8723bs_nic.bin \
    $out/lib/firmware/rtlwifi/rtl8723bs_nic.bin
  install -Dm444 ${../licenses/LICENCE.rtlwifi_firmware.txt} \
    $out/lib/firmware/rtlwifi/LICENCE.rtlwifi_firmware.txt
''

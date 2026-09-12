{ pkgs }:
# Obtain the blob through nixpkgs, which retains its upstream provenance and
# licensing. Do not vendor Realtek firmware into this repository.
pkgs.runCommand "mini-m8s-rtl8723bs-firmware" { } ''
  install -Dm444 ${pkgs.linux-firmware}/lib/firmware/rtlwifi/rtl8723bs_nic.bin \
    $out/lib/firmware/rtlwifi/rtl8723bs_nic.bin
''

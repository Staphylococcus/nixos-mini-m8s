{ pkgs, kernel }:
pkgs.runCommand "mini-m8s-linux-dtbs" { nativeBuildInputs = [ pkgs.dtc ]; } ''
  mkdir -p $out/amlogic
  dtb=$out/amlogic/meson-gxbb-mini-m8s-sd-only.dtb
  cp ${kernel}/dtbs/amlogic/meson-gxbb-p201.dtb "$dtb"
  chmod u+w "$dtb"

  fdtput -t s "$dtb" / model 'Mini M8S (provisional P201 wiring; SD-only)'
  fdtput -t s "$dtb" /soc/apb@d0000000/mmc@74000 status disabled
  fdtput -t s "$dtb" /soc/apb@d0000000/mmc@70000 status okay
  fdtput -t i "$dtb" /soc/apb@d0000000/mmc@70000 max-frequency 25000000
  fdtput -t s "$dtb" /soc/ethernet@c9410000 status disabled
  fdtput -t s "$dtb" /aliases mmc0 /soc/apb@d0000000/mmc@72000
  fdtput -t s "$dtb" /aliases mmc1 /soc/apb@d0000000/mmc@70000
  fdtput -d "$dtb" /aliases mmc2
  fdtput -t x "$dtb" /memory@0 reg 0 0 0 80000000
  fdtput -t i "$dtb" /soc/apb@d0000000/mmc@72000 max-frequency 25000000
  fdtput "$dtb" /soc/apb@d0000000/mmc@72000 no-1-8-v
  # The Meson GX Linux driver does not parse no-1-8-v. Remove the
  # inherited UHS capabilities explicitly to prevent 1.8 V negotiation.
  for mode in sd-uhs-sdr12 sd-uhs-sdr25 sd-uhs-sdr50; do
    fdtput -d "$dtb" /soc/apb@d0000000/mmc@72000 "$mode"
  done
  ! fdtget -p "$dtb" /soc/apb@d0000000/mmc@72000 | grep -q '^sd-uhs-'

  test "$(fdtget "$dtb" /soc/apb@d0000000/mmc@74000 status)" = disabled
  test "$(fdtget "$dtb" /soc/apb@d0000000/mmc@70000 status)" = okay
  test "$(fdtget "$dtb" /soc/ethernet@c9410000 status)" = disabled
  test "$(fdtget "$dtb" /soc/apb@d0000000/mmc@72000 status)" = okay
  test "$(fdtget -t x "$dtb" /memory@0 reg)" = '0 0 0 80000000'
''

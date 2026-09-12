# Hardware status

The port was tested on one original Mini M8S with an S905/GXBB revision-C
SoC, 2 GiB RAM and RTL8723BS SDIO Wi-Fi (`024c:b723`). P201 wiring is used
as a provisional baseline. The exact PCB revision has not been identified.
This does not establish compatibility with Mini M8S II, S905X devices,
other RAM sizes or boxes sold under similar names.

| Component | Evidence |
| --- | --- |
| SD root filesystem | Boots read-write; partition/filesystem expansion verified |
| SD timing | 4-bit, 25 MHz, 3.3 V; inherited UHS flags removed |
| USB keyboard | Interactive Linux console works |
| HDMI | Console works on the tested monitor; another TV lost signal |
| Wi-Fi | RTL8723BS association, DHCP and internet access verified |
| Persistent services | Wi-Fi and key-authenticated SSH passed a cold boot |
| CPUs | Tested with `maxcpus=1`; all-core stability not established |
| Internal eMMC | Disabled in the Linux and U-Boot device trees |
| Ethernet | Disabled pending board/PHY identification |

The tested generation used Linux 6.18.50, NixOS 26.05 and U-Boot 2026.07.
The module defaults retain the conservative CPU and console settings.
Removing a workaround is a new hardware test, not a validated optimization.

The standard NixOS wireless service failed to associate in two trials;
reverting restored the connection. The responsible difference has not been
isolated. The optional service here preserves the successful root-run
wpa_supplicant invocation and runtime configuration model.

The extraction changes packaging and configuration interfaces. Its packages
and generated files have passed build and structural checks, but the new
package output itself has not yet had a hardware boot test.

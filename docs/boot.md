# Boot integration

The supported path is factory firmware → SD launcher → modern U-Boot →
Linux EFI stub. The underside recovery button selects the one-shot SD
launcher while power is connected. Release it when the boot screen appears.
A recovery-button power-on is still required for each SD boot.

The vendor launchers load raw U-Boot into RAM and jump to it. They do not
save a firmware environment or install persistent multiboot. Each legacy
Amlogic script conditional/loop stays on one physical line.

## SD layout assumptions

The boot tools assume SD is U-Boot `mmc 0` with:

1. A FAT32 partition containing the `firmware/` files.
2. An unencrypted ext4 NixOS root partition containing `/nix/store` and the
   staged `/boot/nixos` payloads.

The demonstrated card used an MBR, an 8 MiB initial gap and a 64 MiB FAT32
partition. Labels `M8S_BOOT` and `M8S_NIXOS` are examples, not unique device
identifiers. Re-identify a target before installing files. No formatter or
disk-selection script is provided by this library.

The factory firmware still runs before our launcher. Removing the SD
returns control to the existing factory boot/recovery path; this port does
not repair any pre-existing Android failure.

## Installing staged files

Prepare the NixOS root filesystem using a consuming image configuration or
other established NixOS installation workflow. It must contain the full
closure of the system passed to `make-boot`, not just a copied kernel.

With the intended SD partitions mounted, back up their boot files. Copy the
staged `root/boot/nixos/` contents to `/boot/nixos/` on the root partition,
then the staged `firmware/` contents to the FAT partition. Check the manifest
on FAT and compare the copied kernel/initrd against the staged files. Sync,
unmount, and use the recovery-button power-on procedure.

The tool deliberately leaves mounting and copying to the consuming setup;
it cannot identify the user's intended physical SD card from a flake.

## Updating a generation

The selected system is encoded in the generated EFI script. Updating only
Nix's system profile or extlinux menu does **not** update that selection.
For every new generation:

1. Build and retain the selected system closure in a Nix profile/GC root.
2. Run `make-boot` for that system into a fresh staging directory.
3. Install and verify the new payloads and EFI files as above, preserving a
   complete previous set of EFI script, DTB, kernel/initrd and system closure.
4. Test the new boot before removing the previous generation.

The generator uses these addresses and checks them against device-tree
reservations:

| Payload | Address |
| --- | --- |
| Script | `0x08000000` |
| Device tree | `0x08008000` |
| Kernel | `0x08080000` |
| Initrd | `0x13000000` |

The earlier script address `0x06000000` overlapped secure reserved memory.
A regression test rejects it. Structural checks do not replace U-Boot's
runtime memory checks or a hardware boot test.

Upstream references: [Meson load addresses](https://github.com/u-boot/u-boot/blob/v2026.07/include/configs/meson64.h),
[EFI command](https://docs.u-boot.org/en/latest/usage/cmd/bootefi.html),
[GXBB P201 baseline](https://github.com/u-boot/u-boot/blob/v2026.07/configs/p201_defconfig).

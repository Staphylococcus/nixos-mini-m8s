# nixos-mini-m8s

Experimental NixOS support for the **original Mini M8S: Amlogic S905/GXBB,
2 GiB RAM, RTL8723BS Wi-Fi**. This is a reusable board module and boot-tool
library. Accounts, SSH keys, Wi-Fi credentials and machine policy belong in
a consuming configuration, such as a separate `nix-config` repository.

The underlying port has booted from microSD, joined Wi-Fi automatically and
accepted SSH after a cold boot. The extracted packages are build-tested;
their newly generated boot files have not yet been booted on hardware.
See [hardware status](docs/hardware.md) for the exact scope and limitations.

## Use from another flake

Add the board-support flake to your configuration:

```nix
{
  inputs.mini-m8s.url = "github:Staphylococcus/nixos-mini-m8s";
  inputs.nixpkgs.follows = "mini-m8s/nixpkgs";

  outputs = { nixpkgs, mini-m8s, ... }: {
    nixosConfigurations.mini-m8s = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        mini-m8s.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Start with [examples/configuration.nix](examples/configuration.nix), add your
own SSH public key and adapt the filesystem labels. The core module does
not create a user, enable SSH, select a hostname/timezone, or enable console
autologin. The example makes those separate choices explicitly.

| Option | Default | Purpose |
| --- | --- | --- |
| `hardware.miniM8s.enable` | `false` | Enable board support |
| `hardware.miniM8s.singleCore` | `true` | Retain the tested `maxcpus=1` workaround |
| `hardware.miniM8s.verboseBoot` | `true` | Retain bring-up console diagnostics |
| `hardware.miniM8s.wifi.enable` | `false` | Enable the tested supplicant service |
| `hardware.miniM8s.wifi.configFile` | `/var/lib/mini-m8s/wpa_supplicant.conf` | Runtime configuration, outside the Nix store |

The Wi-Fi service requires a root-owned file with mode 0400 or 0600. A
missing file skips the service, allowing initial provisioning. Do not run
it alongside NetworkManager or `networking.wireless`; the module rejects
that combination. See [Wi-Fi setup](docs/wifi.md).

The lock file pins the versions used for the port. The example follows that
nixpkgs pin. Using another pin requires rechecking the kernel, device tree
and boot payload layout.

## Build and stage boot files

On x86_64 Linux or aarch64 Linux:

```sh
nix flake check
nix build .#bootloader .#dtb
```

The x86_64 U-Boot package cross-compiles for ARM64. Full NixOS system builds
still require an ARM64 builder. Build the consuming configuration's system
closure first, then make boot files with a machine that can read that
closure from its Nix store:

```sh
nix run .#make-boot -- \
  --system /path/to/your/system-result \
  --output ../staged-mini-m8s
```

The command reads the selected system's `boot.json`, kernel, initrd and
Mini M8S device tree. It generates the EFI script rather than embedding one
machine's store paths in this repository. It checks script CRCs, kernel
format, SD settings, payload overlap and reserved memory before producing:

- `firmware/`: vendor launchers, raw U-Boot, EFI script, DTB and checksums.
- `root/boot/nixos/`: the matching kernel and initrd.
- `boot-manifest.json`: selected system and load ranges.

This command stages ordinary files. It does not mount, format or write a
block device, and the output is **not a complete OS image**. The target SD
must already contain the selected NixOS system closure and a suitable root
filesystem. See [boot integration](docs/boot.md) for partition assumptions,
installation, generation updates and recovery.

There is no full-image target in this repository. The early port's image
target used an obsolete direct boot path; it has not been carried over as
if it reproduced the working EFI setup.

## Validation

The checks exercise the exported NixOS module and the boot generator,
including the original reserved-memory collision and accidental UHS
reintroduction. U-Boot's build also checks the required EFI/USB options,
disabled internal MMC access and lack of persistent environment storage.
Build and end-to-end staging results are summarized in
[validation](docs/validation.md).

Original source in this repository is [MIT licensed](LICENSE). U-Boot,
Linux device trees and firmware retain their upstream licenses; see
[third-party provenance](NOTICE.md). No firmware or compiled boot binaries
are committed here.

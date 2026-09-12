# Validation

The port behind this repository passed a hardware cold boot with automatic
Wi-Fi and key-based SSH on one original 2 GiB Mini M8S. The extracted
packaging has a separate validation boundary: its newly generated boot
files have not yet been booted on the box.

Repository checks:

```sh
nix flake check --all-systems --no-build
nix build .#checks.x86_64-linux.boot-tool .#checks.x86_64-linux.module-evaluation
nix build .#make-boot .#firmware
```

The boot-tool test suite covers device-tree invariants, the previously
failing reserved-memory address, oversized payloads, accidental UHS
reintroduction, script-argument escaping and U-Boot header/payload CRCs.
The module check evaluates a complete ARM64 system and verifies that the
core does not enable SSH or console autologin.

The x86_64 `make-boot` build includes a cross-compiled ARM64 U-Boot and its
build-time configuration checks. End-to-end staging was exercised against
an existing NixOS closure containing the real Linux 6.18.50 kernel and
initrd, plus the extracted Mini M8S device tree. All staged firmware
checksums passed. The staged result remained an ordinary directory; no
hardware was changed by this repository's validation.

The firmware selected through nixpkgs and the generated device tree are
also compared against the corresponding assets from the working port.
Personal keys, credentials, addresses, host identifiers and hardware serial
numbers are excluded from the repository.

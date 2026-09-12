# Third-party provenance

The repository's original Nix, Python, overlay and launcher source is
covered by the root MIT license. That license does not relicense upstream
components or generated binary artifacts.

- **U-Boot:** fetched at the revision in `flake.lock`; built from the
  upstream P201 configuration with the local overlay and config fragment.
  Upstream licensing is described in its
  [Licenses/README](https://github.com/u-boot/u-boot/blob/v2026.07/Licenses/README).
- **Linux device tree:** generated from the selected kernel's GXBB P201
  DTB. The original Linux sources and resulting derivative artifacts retain
  their applicable upstream licenses.
- **RTL8723BS firmware:** selected from nixpkgs' `linux-firmware` package.
  The repository does not vendor the blob. Its upstream origin, version and
  firmware-license classification are recorded in the pinned
  [nixpkgs package](https://github.com/NixOS/nixpkgs/blob/21a67dc470149f337cecafbe965d8d252a390518/pkgs/by-name/li/linux-firmware/package.nix).

Only source and tests belong in this Git repository. Staged boot files and
full disk images are build outputs with their respective upstream licenses.

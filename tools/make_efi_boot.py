#!/usr/bin/env python3
"""Stage Mini M8S boot files; never mount, format, or write a block device."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import zlib

SCRIPT_ADDR = 0x08000000
FDT_ADDR = 0x08008000
KERNEL_ADDR = 0x08080000
INITRD_ADDR = 0x13000000
DTB_NAME = "amlogic/meson-gxbb-mini-m8s-sd-only.dtb"
STORE_PATH = re.compile(r"/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._-]+(?:/[A-Za-z0-9+._-]+)*")


def fdt(data):
    if len(data) < 40:
        raise ValueError("truncated device tree")
    magic, total, pos, strings, reservations = struct.unpack_from(">5I", data)
    if magic != 0xD00DFEED or total != len(data):
        raise ValueError("invalid device tree header")
    nodes, stack = {}, []
    while True:
        token, = struct.unpack_from(">I", data, pos)
        pos += 4
        if token == 1:
            end = data.index(0, pos)
            stack.append(data[pos:end].decode())
            nodes["/".join(stack)] = {}
            pos = (end + 4) & ~3
        elif token == 2:
            stack.pop()
        elif token == 3:
            size, offset = struct.unpack_from(">II", data, pos)
            pos += 8
            name = data[strings + offset:data.index(0, strings + offset)].decode()
            if pos + size > len(data):
                raise ValueError("truncated device tree property")
            nodes["/".join(stack)][name] = data[pos:pos + size]
            pos = (pos + size + 3) & ~3
        elif token == 4:
            continue
        elif token == 9:
            break
        else:
            raise ValueError(f"invalid device tree token {token}")
    ranges = []
    parent = nodes.get("/reserved-memory", {})
    if parent:
        if parent.get("#address-cells") != struct.pack(">I", 2) or parent.get("#size-cells") != struct.pack(">I", 2):
            raise ValueError("expected 64-bit reserved-memory cells")
        for name, properties in nodes.items():
            if name.startswith("/reserved-memory/") and "reg" in properties and properties.get("status") != b"disabled\0":
                if len(properties["reg"]) % 16:
                    raise ValueError("invalid reserved-memory reg")
                for start, size in struct.iter_unpack(">QQ", properties["reg"]):
                    ranges.append((start, start + size))
    while True:
        start, size = struct.unpack_from(">QQ", data, reservations)
        reservations += 16
        if start == size == 0:
            break
        ranges.append((start, start + size))
    return nodes, ranges


def validate_layout(regions, reservations):
    for index, (name, start, size) in enumerate(regions):
        if size <= 0 or start + size >= 0x40000000:
            raise ValueError(f"{name} exceeds the conservative RAM load range")
        if any(start < end and begin < start + size for begin, end in reservations):
            raise ValueError(f"{name} overlaps reserved memory")
        for other, begin, length in regions[index + 1:]:
            if start < begin + length and begin < start + size:
                raise ValueError(f"{name} overlaps {other}")


def validate_tree(data):
    nodes, ranges = fdt(data)
    sd = nodes["/soc/apb@d0000000/mmc@72000"]
    if sd.get("status") != b"okay\0" or any(p.startswith("sd-uhs-") for p in sd):
        raise ValueError("SD must be enabled with UHS disabled")
    if sd.get("max-frequency") != struct.pack(">I", 25000000):
        raise ValueError("expected the tested 25 MHz SD limit")
    for node in ["/soc/apb@d0000000/mmc@74000", "/soc/ethernet@c9410000"]:
        if nodes[node].get("status") != b"disabled\0":
            raise ValueError("this boot tool supports the tested SD-only device tree")
    if nodes["/memory@0"].get("reg") != struct.pack(">4I", 0, 0, 0, 0x80000000):
        raise ValueError("this boot tool supports the 2 GiB Mini M8S")
    return ranges


def store_path(value):
    if not isinstance(value, str) or not STORE_PATH.fullmatch(value) or any(p in {".", ".."} for p in Path(value).parts):
        raise ValueError("expected a plain absolute Nix store path")
    return Path(value)


def boot_name(path):
    # Matches the generic-extlinux-compatible builder's flat payload names.
    return str(path).removeprefix("/nix/store/").replace("/", "-")


def script(init, kernel_name, initrd_name, params):
    if any(param.startswith("init=") for param in params):
        raise ValueError("kernel parameters must not override the selected system init")
    args = " ".join(["init=" + str(init), *params])
    if any(ord(c) < 32 or c == "'" for c in args):
        raise ValueError("unsupported quote or control character in kernel arguments")
    return f"""# Generated from the selected NixOS system. SD reads only.
echo Mini M8S: booting NixOS through EFI
if load mmc 0:1 0x{FDT_ADDR:08x} mini-m8s.dtb; then
  if load mmc 0:2 0x{INITRD_ADDR:08x} /boot/nixos/{initrd_name}; then
    setenv m8s_initrd_size ${{filesize}}
    if load mmc 0:2 0x{KERNEL_ADDR:08x} /boot/nixos/{kernel_name}; then
      setenv m8s_kernel_size ${{filesize}}
      setenv bootargs '{args}'
      bootefi 0x{KERNEL_ADDR:08x}:${{m8s_kernel_size}} 0x{INITRD_ADDR:08x}:${{m8s_initrd_size}} 0x{FDT_ADDR:08x}
      echo EFI boot returned - stopped
    else
      echo Kernel load failed - stopped
    fi
  else
    echo Initrd load failed - stopped
  fi
else
  echo Device tree load failed - stopped
fi
""".encode()


def validate_script(compiled, source):
    if len(compiled) < 72:
        raise ValueError("truncated U-Boot script")
    header = bytearray(compiled[:64])
    magic, crc, _, size, _, _, payload_crc = struct.unpack_from(">7I", header)
    header[4:8] = bytes(4)
    if (magic != 0x27051956 or size != len(compiled) - 64 or
            zlib.crc32(header) != crc or zlib.crc32(compiled[64:]) != payload_crc or
            compiled[64:72] != struct.pack(">II", len(source), 0) or compiled[72:] != source):
        raise ValueError("invalid U-Boot script lengths or checksums")


def generate(system, output, bootloader):
    system = system.resolve()
    output = output.absolute()
    if output.exists():
        raise ValueError("output already exists; choose an empty staging destination")
    spec = json.loads((system / "boot.json").read_text())["org.nixos.bootspec.v1"]
    if spec["system"] != "aarch64-linux":
        raise ValueError("expected an aarch64-linux system")
    kernel, initrd, init = (store_path(spec[k]) for k in ["kernel", "initrd", "init"])
    if not init.is_file():
        raise ValueError("selected system init is missing")
    params = spec["kernelParams"]
    if not isinstance(params, list) or not all(isinstance(p, str) for p in params):
        raise ValueError("invalid kernel parameters")
    with kernel.open("rb") as stream:
        header = stream.read(64)
    if len(header) != 64 or header[:2] != b"MZ" or header[56:60] != b"ARM\x64":
        raise ValueError("expected an uncompressed ARM64 kernel with its EFI stub")
    dtb = (system / "dtbs" / DTB_NAME).read_bytes()
    reservations = validate_tree(dtb)
    _, uboot_reservations = fdt((bootloader / "u-boot.dtb").read_bytes())
    source = script(init, boot_name(kernel), boot_name(initrd), params)
    regions = [("script", SCRIPT_ADDR, len(source) + 72), ("FDT", FDT_ADDR, len(dtb)),
               ("kernel", KERNEL_ADDR, kernel.stat().st_size), ("initrd", INITRD_ADDR, initrd.stat().st_size)]
    validate_layout(regions, reservations + uboot_reservations)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".mini-m8s-", dir=output.parent) as temp:
        staged = Path(temp) / "staged"
        firmware = staged / "firmware"
        root_boot = staged / "root/boot/nixos"
        firmware.mkdir(parents=True)
        root_boot.mkdir(parents=True)
        for name in ["u-boot.ext", "aml_autoscript", "s905_autoscript", "aml_autoscript.cmd", "s905_autoscript.cmd"]:
            shutil.copyfile(bootloader / name, firmware / name)
        (firmware / "mini-m8s.dtb").write_bytes(dtb)
        (firmware / "efi-console.cmd").write_bytes(source)
        subprocess.run(["mkimage", "-A", "arm64", "-O", "linux", "-T", "script", "-C", "none",
                        "-n", "Mini M8S NixOS EFI boot", "-d", str(firmware / "efi-console.cmd"),
                        str(firmware / "efi-console.scr")], check=True,
                       env={**os.environ, "SOURCE_DATE_EPOCH": "0"}, stdout=subprocess.DEVNULL)
        validate_script((firmware / "efi-console.scr").read_bytes(), source)
        for payload in [kernel, initrd]:
            shutil.copyfile(payload, root_boot / boot_name(payload))
        manifest = "".join(hashlib.sha256(p.read_bytes()).hexdigest() + "  " + p.name + "\n"
                           for p in sorted(firmware.iterdir()))
        (firmware / "SHA256SUMS").write_text(manifest)
        report = {"system": str(system), "kernel": str(kernel), "initrd": str(initrd),
                  "regions": [{"name": n, "start": hex(a), "endExclusive": hex(a + s)} for n, a, s in regions]}
        (staged / "boot-manifest.json").write_text(json.dumps(report, indent=2) + "\n")
        staged.rename(output)
    print(f"Staged boot files in {output}; no device was written.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--system", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--bootloader-files", type=Path, required=True)
    args = parser.parse_args()
    try:
        generate(args.system, args.output, args.bootloader_files)
    except (ValueError, KeyError, OSError, struct.error, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Mini M8S boot generation failed: {error}\n")


if __name__ == "__main__":
    main()

import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

import make_efi_boot as boot


class BootTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dtb = Path(os.environ["MINI_M8S_DTB"]).read_bytes()
        cls.init = "/nix/store/" + "a" * 32 + "-nixos-system-example/init"

    def test_device_tree_preserves_tested_board_settings(self):
        boot.validate_tree(self.dtb)
        nodes, _ = boot.fdt(self.dtb)
        sdio = nodes["/soc/apb@d0000000/mmc@70000"]
        self.assertEqual(sdio["status"], b"okay\0")
        self.assertEqual(sdio["max-frequency"], struct.pack(">I", 25000000))
        self.assertEqual(nodes["/aliases"]["mmc0"], b"/soc/apb@d0000000/mmc@72000\0")
        self.assertEqual(nodes["/soc/apb@d0000000/mmc@72000"]["bus-width"], struct.pack(">I", 4))

    def test_rejects_reintroduced_uhs(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "bad.dtb"
            path.write_bytes(self.dtb)
            subprocess.run(["fdtput", str(path), "/soc/apb@d0000000/mmc@72000", "sd-uhs-sdr50"], check=True)
            with self.assertRaisesRegex(ValueError, "UHS"):
                boot.validate_tree(path.read_bytes())

    def test_truncated_device_tree(self):
        with self.assertRaises(ValueError):
            boot.fdt(b"\x00" * 20)

    def test_original_failing_script_address_is_rejected(self):
        _, reservations = boot.fdt(self.dtb)
        with self.assertRaisesRegex(ValueError, "reserved memory"):
            boot.validate_layout([("old script", 0x06000000, 1024)], reservations)

    def test_working_load_layout(self):
        _, reservations = boot.fdt(self.dtb)
        boot.validate_layout([
            ("script", boot.SCRIPT_ADDR, 4096), ("FDT", boot.FDT_ADDR, len(self.dtb)),
            ("kernel", boot.KERNEL_ADDR, 64141824), ("initrd", boot.INITRD_ADDR, 24743050),
        ], reservations)

    def test_large_script_cannot_overwrite_device_tree(self):
        with self.assertRaisesRegex(ValueError, "overlaps FDT"):
            boot.validate_layout([("script", boot.SCRIPT_ADDR, 0x9000), ("FDT", boot.FDT_ADDR, len(self.dtb))], [])

    def test_large_kernel_cannot_enter_secure_memory(self):
        _, reservations = boot.fdt(self.dtb)
        with self.assertRaisesRegex(ValueError, "reserved memory"):
            boot.validate_layout([("kernel", boot.KERNEL_ADDR, 0x10000000)], reservations)

    def test_boot_arguments_cannot_break_script_quoting(self):
        for value in ["bad'argument", "bad\nargument", "bad\rargument", "bad\0argument"]:
            with self.subTest(value=repr(value)), self.assertRaises(ValueError):
                boot.script(self.init, "kernel-Image", "initrd-initrd", [value])

    def test_store_paths_cannot_inject_boot_commands(self):
        for value in ["/tmp/Image", self.init + "; reset", self.init + "\n", self.init + "/../init"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                boot.store_path(value)

    def test_kernel_parameters_cannot_select_another_init(self):
        with self.assertRaisesRegex(ValueError, "override"):
            boot.script(self.init, "kernel-Image", "initrd-initrd", ["init=/bin/sh"])

    def test_payload_naming_matches_extlinux(self):
        path = boot.store_path("/nix/store/" + "b" * 32 + "-linux-example/Image")
        self.assertEqual(boot.boot_name(path), "b" * 32 + "-linux-example-Image")

    def test_mkimage_header_payload_and_corruption(self):
        source = boot.script(self.init, "kernel-Image", "initrd-initrd", ["console=tty0", "maxcpus=1"])
        with tempfile.TemporaryDirectory() as temp:
            cmd, scr = Path(temp) / "boot.cmd", Path(temp) / "boot.scr"
            cmd.write_bytes(source)
            subprocess.run(["mkimage", "-A", "arm64", "-O", "linux", "-T", "script", "-C", "none",
                            "-n", "Mini M8S test", "-d", str(cmd), str(scr)], check=True, stdout=subprocess.DEVNULL)
            data = scr.read_bytes()
            boot.validate_script(data, source)
            corrupted = data[:-1] + bytes([data[-1] ^ 1])
            with self.assertRaisesRegex(ValueError, "checksums"):
                boot.validate_script(corrupted, source)


if __name__ == "__main__":
    unittest.main()

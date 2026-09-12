{
  description = "Experimental NixOS support for the original Mini M8S (S905/GXBB, 2 GiB)";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    uboot-src = {
      url = "github:u-boot/u-boot/v2026.07";
      flake = false;
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      uboot-src,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forSystems = nixpkgs.lib.genAttrs systems;
      armPkgs = import nixpkgs { system = "aarch64-linux"; };
      toolSource = builtins.path {
        path = ./tools/make_efi_boot.py;
        name = "make_efi_boot.py";
      };
      toolsSource = builtins.path {
        path = ./tools;
        name = "mini-m8s-boot-tools";
      };
      testsSource = builtins.path {
        path = ./tests;
        name = "mini-m8s-tests";
      };
      evaluationHost = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.nixosModules.default
          ./tests/host.nix
        ];
      };
    in
    {
      nixosModules = {
        default = import ./modules;
        mini-m8s = self.nixosModules.default;
      };
      packages = forSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          uboot = import ./packages/uboot.nix {
            inherit pkgs;
            src = uboot-src;
          };
          bootloader = import ./packages/bootloader-files.nix { inherit pkgs uboot; };
        in
        {
          inherit uboot bootloader;
          default = bootloader;
          dtb = import ./packages/linux-dtbs.nix {
            inherit pkgs;
            kernel = armPkgs.linuxPackages.kernel;
          };
          firmware = import ./packages/firmware.nix { inherit pkgs; };
          make-boot = pkgs.writeShellApplication {
            name = "mini-m8s-make-boot";
            runtimeInputs = [
              pkgs.python3
              pkgs.ubootTools
            ];
            text = ''exec python3 ${toolSource} --bootloader-files ${bootloader} "$@"'';
          };
        }
      );
      checks = forSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          boot-tool =
            pkgs.runCommand "mini-m8s-boot-tool-check"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.ubootTools
                  pkgs.dtc
                ];
              }
              ''
                export PYTHONDONTWRITEBYTECODE=1
                export PYTHONPATH=${toolsSource}
                export MINI_M8S_DTB=${self.packages.${system}.dtb}/amlogic/meson-gxbb-mini-m8s-sd-only.dtb
                python3 -m unittest discover -s ${testsSource} -p 'test_*.py' -v
                touch $out
              '';
          module-evaluation =
            assert evaluationHost.config.hardware.miniM8s.enable;
            assert !evaluationHost.config.services.openssh.enable;
            assert evaluationHost.config.services.getty.autologinUser == null;
            pkgs.runCommand "mini-m8s-module-evaluation" {
              evaluatedSystem = builtins.unsafeDiscardStringContext evaluationHost.config.system.build.toplevel.drvPath;
            } ''printf '%s\n' "$evaluatedSystem" > $out'';
        }
      );
      formatter = forSystems (system: (import nixpkgs { inherit system; }).nixfmt);
    };
}

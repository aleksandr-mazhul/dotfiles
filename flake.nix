{
  description = "NixOS and Home Manager for stranger";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    vibepanel.url = "github:prankstr/vibepanel/v0.17.2";
    vibepanel.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, disko, vibepanel, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      installScript = pkgs.writeShellScriptBin "install-machine" ''
        export FLAKE_ROOT=${./.}
        export PATH=${nixpkgs.lib.makeBinPath [
          pkgs.util-linux
          disko.packages.${system}.disko
          disko.packages.${system}.disko-install
        ]}:$PATH
        exec ${./nix/install-machine.sh} "$@"
      '';
      shared = [
        nixos-hardware.nixosModules.common-cpu-intel
        nixos-hardware.nixosModules.common-pc-ssd
        home-manager.nixosModules.home-manager
        ./nix/system.nix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.stranger = ./nix/home.nix;
        }
        {
          environment.systemPackages = [
            vibepanel.packages.${system}.default
          ];
        }
      ];
    in
    {
      nixosConfigurations.stranger = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = shared ++ [
          disko.nixosModules.disko
          ./nix/disko.nix
          { nixpkgs.config.allowUnfree = true; }
          { environment.systemPackages = [ installScript ]; }
        ];
      };

      nixosConfigurations.live = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = shared ++ [
          ./nix/live.nix
          { nixpkgs.config.allowUnfree = true; }
          { environment.systemPackages = [ installScript ]; }
        ];
      };

      apps.${system}.install = {
        type = "app";
        program = "${installScript}/bin/install-machine";
      };

      packages.${system}.iso = self.nixosConfigurations.live.config.system.build.isoImage;

      checks.${system} = {
        package-map = pkgs.runCommand "package-map" { } ''
          echo "packages=${toString (builtins.length (import ./nix/package-map.nix { inherit (pkgs) lib; inherit pkgs; }).packages)}" > $out
        '';
        install-guard = pkgs.runCommand "install-guard" { } ''
          set -e
          if ${installScript}/bin/install-machine; then
            echo "install-machine should refuse without a disk" >&2
            exit 1
          fi
          ${installScript}/bin/install-machine --dry-run /dev/nvme0n1 > "$out"
          grep -q 'disko-install --disk main /dev/nvme0n1' "$out"
          ${pkgs.bash}/bin/sh ${./nix/install-guard.sh} ${./nix/install-machine.sh}
          echo "unit-refusals ok" >> "$out"
        '';
        desktop = import ./nix/test.nix {
          inherit pkgs;
          modules = shared;
        };
      };
    };
}

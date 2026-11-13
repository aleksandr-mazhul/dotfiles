{
  description = "NixOS and Home Manager for stranger";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, disko, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
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
      ];
    in
    {
      nixosConfigurations.stranger = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = shared ++ [
          disko.nixosModules.disko
          ./nix/disko.nix
          { nixpkgs.config.allowUnfree = true; }
        ];
      };

      checks.${system} = {
        package-map = pkgs.runCommand "package-map" { } ''
          echo "packages=${toString (builtins.length (import ./nix/package-map.nix { inherit (pkgs) lib; inherit pkgs; }).packages)}" > $out
        '';
        desktop = import ./nix/test.nix {
          inherit pkgs;
          modules = shared;
        };
      };
    };
}

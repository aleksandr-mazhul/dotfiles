# Live ISO of the same desktop. Boot lands in the Hyprland session.
# install-machine on this image formats only the disk you pass it.
{ modulesPath, lib, ... }:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  isoImage.edition = "stranger";
  isoImage.volumeID = "STRANGER";
  isoImage.squashfsCompression = "zstd -Xcompression-level 1";
  # iso-image.nix leaves both off. A new PC is UEFI and the image is written to USB.
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "stranger";
  users.users.stranger.initialPassword = "live";
}

{ config, lib, pkgs, ... }:
let
  mapped = import ./package-map.nix { inherit lib pkgs; };
in
{
  networking.hostName = "stranger";
  time.timeZone = "Europe/Minsk";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.cpu.intel.updateMicrocode = true;

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
  };

  hardware.i2c.enable = true;
  hardware.bluetooth.enable = true;

  programs.hyprland.enable = true;
  programs.hyprland.withUWSM = true;
  programs.fish.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "hyprland-uwsm";

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  networking.networkmanager.enable = true;
  services.printing.enable = true;
  virtualisation.docker.enable = true;
  services.openssh.enable = true;
  zramSwap.enable = true;

  users.users.stranger = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "i2c" "video" "docker" "networkmanager" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBFscRM67/+flMNYhje5HXSGbNdiQ3m5bKA4vvEc2fm9 map07102007@gmail.com"
    ];
  };

  environment.systemPackages = mapped.packages ++ [
    (pkgs.tesseract.override { enableLanguages = [ "eng" "rus" ]; })
  ];

  fonts.packages = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome
    powerline-fonts
  ];

  services.udev.extraRules = ''
    ${builtins.readFile ../system/etc/udev/rules.d/50-usb-hid-no-autosuspend.rules}
    ${builtins.readFile ../system/etc/udev/rules.d/59-vial.rules}
    ACTION=="add|change", SUBSYSTEM=="powercap", KERNEL=="intel-rapl*", RUN+="${pkgs.coreutils}/bin/chmod o+r /sys/%p/energy_uj"
  '';

  system.stateVersion = "25.11";
}

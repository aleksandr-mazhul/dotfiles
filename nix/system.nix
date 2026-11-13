{ config, lib, pkgs, ... }:
let
  mapped = import ./package-map.nix { inherit lib pkgs; };
  sddmAdaptive = pkgs.runCommand "sddm-adaptive-theme" { } ''
    mkdir -p "$out/share/sddm/themes/adaptive"
    cp -a ${../sddm/themes/adaptive}/. "$out/share/sddm/themes/adaptive/"
  '';
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
  hardware.uinput.enable = true;

  programs.hyprland.enable = true;
  programs.hyprland.withUWSM = true;
  programs.fish.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.theme = "${sddmAdaptive}/share/sddm/themes/adaptive";
  services.displayManager.sddm.settings.Theme = {
    CursorTheme = "Adwaita";
    Font = "Adwaita Sans";
  };
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
  services.openssh.settings.PasswordAuthentication = false;
  zramSwap.enable = true;

  users.users.stranger = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "i2c" "video" "docker" "networkmanager" "uinput" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBFscRM67/+flMNYhje5HXSGbNdiQ3m5bKA4vvEc2fm9 map07102007@gmail.com"
    ];
  };

  # Arch renamed swww to awww. The rice still execs swww / swww-daemon
  # (bootstrap.sh only symlinks those on the Arch install).
  swwwCompat = pkgs.runCommand "swww-compat" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.awww}/bin/awww "$out/bin/swww"
    ln -s ${pkgs.awww}/bin/awww-daemon "$out/bin/swww-daemon"
  '';

  environment.systemPackages = mapped.packages ++ [
    (pkgs.tesseract.override { enableLanguages = [ "eng" "rus" ]; })
    pkgs.python3
    sddmAdaptive
    swwwCompat
  ];
  # The default profile does not link /share/sddm, so the greeter theme would
  # stay invisible outside the SDDM unit.
  environment.pathsToLink = [ "/share/sddm" ];

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

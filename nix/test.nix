# Boots the same system without the Kingston disko layout, on a virtio GPU,
# and checks that the account, units, config files, and Hyprland come up.
# NVIDIA, the real monitors, and the keyboard are not in this VM.
{ pkgs, modules }:
pkgs.testers.runNixOSTest {
  name = "stranger-desktop";
  nodes.machine = { lib, ... }: {
    imports = modules;
    services.displayManager.sddm.enable = lib.mkForce false;
    services.xserver.videoDrivers = lib.mkForce [ "virtio" ];
    hardware.nvidia.open = lib.mkForce false;
    services.getty.autologinUser = "stranger";
    users.users.stranger.initialPassword = "test";
    programs.bash.loginShellInit = ''
      if [ "$(tty)" = "/dev/tty1" ]; then
        exec Hyprland
      fi
    '';
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;
    virtualisation.qemu.options = [
      "-vga none"
      "-device virtio-gpu-pci"
    ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("id stranger")
    machine.succeed("id stranger | grep -q '(input)'")
    machine.succeed("id stranger | grep -q '(i2c)'")
    machine.succeed("id stranger | grep -q '(video)'")
    machine.succeed("id stranger | grep -q '(docker)'")
    machine.wait_for_unit("NetworkManager.service")
    machine.wait_for_unit("bluetooth.service")
    machine.wait_for_unit("docker.service")
    machine.succeed("test -f /home/stranger/.config/hypr/hyprland.lua")
    machine.succeed("test -f /home/stranger/.config/hypr/monitors.lua")
    machine.succeed("test -f /home/stranger/.config/hypr/binds.lua")
    machine.succeed("test -d /home/stranger/.config/quickshell")
    machine.succeed("test -d /home/stranger/.config/fish")
    machine.succeed("test -d /home/stranger/.config/kitty")
    machine.succeed("test -d /home/stranger/.config/nvim")
    machine.succeed("test -f /home/stranger/.config/kanata/kanata.kbd")
    machine.wait_until_succeeds("pgrep -u stranger -x Hyprland", timeout=180)
  '';
}

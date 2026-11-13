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
    # The account's login shell is fish, so the tty1 handoff has to live there.
    programs.fish.loginShellInit = ''
      if test (tty) = "/dev/tty1"
        exec Hyprland
      end
    '';
    # BlueZ refuses to start unless /sys/class/bluetooth exists. This VM has
    # no adapter, so load the virtual HCI and pull the unit into multi-user.
    boot.kernelModules = [ "hci_vhci" ];
    systemd.services.bluetooth.wantedBy = [ "multi-user.target" ];
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
    machine.succeed("id stranger | grep -q '(uinput)'")
    machine.succeed("command -v python3")
    machine.succeed("command -v qs")
    machine.succeed("command -v kitty")
    machine.succeed("command -v swww-daemon")
    machine.succeed("command -v waypaper")
    machine.succeed("command -v gtk-launch")
    machine.succeed("command -v gio")
    machine.succeed("test -f /run/current-system/sw/share/sddm/themes/adaptive/Main.qml")
    machine.succeed("grep -q 'qs -c rice' /home/stranger/.config/hypr/hyprland.lua")
    machine.succeed("grep -q 'local mainMod' /home/stranger/.config/hypr/binds.lua")
    machine.succeed("test -f /home/stranger/.config/mimeapps.list")
    machine.succeed("grep -q Graphite-Dark /home/stranger/.config/gtk-3.0/settings.ini")
    machine.succeed("grep -q Papirus-Dark /home/stranger/.config/gtk-3.0/settings.ini")
    machine.succeed("test -f /home/stranger/.config/dconf/user.ini")
    machine.succeed("test -f /home/stranger/.config/herdr/config.toml")
    machine.succeed("fc-list : family | grep -q 'Adwaita Sans'")
    machine.succeed("test -d /run/current-system/sw/share/icons/Papirus-Dark")
    machine.succeed("test -f /run/current-system/sw/share/themes/Graphite-Dark/gtk-3.0/gtk.css")
    machine.succeed("test -f /run/current-system/sw/share/themes/Graphite-Dark/gtk-4.0/gtk.css")
    machine.succeed("grep -q '^Name=macOS$' /run/current-system/sw/share/icons/macOS/index.theme")
    machine.succeed("test -d /run/current-system/sw/share/icons/macOS/cursors")
    machine.succeed("test -f /run/current-system/sw/share/icons/macOS-hypr/manifest.hl")
    machine.succeed("command -v codex")
    machine.succeed("command -v opencode")
    machine.succeed("command -v qwen")
    machine.succeed("command -v devin-desktop")
    machine.succeed("command -v jetbrains-toolbox")
    machine.succeed("command -v spicetify")
    machine.succeed("command -v voxtype")
    machine.succeed("test -f /run/current-system/sw/lib/openrgb/plugins/libOpenRGBEffectsPlugin.so")
    # Nix's binary wrapper execs .Hyprland-wrapped, so the comm is
    # ".Hyprland-wrap", not the exact name "Hyprland".
    machine.wait_until_succeeds("pgrep -u stranger Hyprland", timeout=180)
    machine.wait_until_succeeds("pgrep -u stranger quickshell", timeout=90)
  '';
}

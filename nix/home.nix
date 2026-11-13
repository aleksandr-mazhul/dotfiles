{ config, lib, pkgs, ... }:
let
  files = import ./files.nix { inherit lib; };
in
{
  home.username = "stranger";
  home.homeDirectory = "/home/stranger";
  home.stateVersion = "25.11";

  home.packages = [ ];

  home.file = lib.mapAttrs (_: e: {
    source = e.source;
    recursive = true;
  }) files // {
    ".config/dconf/user.ini".source = ../migration/inventory/dconf.ini;
  };

  programs.fish.enable = true;

  # Preferences dumped from the Arch session. Loaded once the user bus exists.
  systemd.user.services.dconf-load = {
    Unit = {
      Description = "Load dconf preferences";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.dconf}/bin/dconf load /";
      StandardInput = "file:%h/.config/dconf/user.ini";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.kanata = {
    Unit = {
      Description = "Kanata keyboard remapper";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kanata}/bin/kanata --nodelay --cfg %h/.config/kanata/kanata.kbd";
      Restart = "on-failure";
      RestartSec = 1;
      Environment = "RUST_LOG=info";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.hid-kbd-swallow = {
    Unit = {
      Description = "Swallow extra HID keyboards";
      After = [ "kanata.service" ];
      Wants = [ "kanata.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "%h/.local/bin/hid-kbd-swallow.py";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.icloud-calendar-sync = {
    Unit.Description = "Sync calendars via qs-calendar.sh";
    Service = {
      Type = "oneshot";
      Environment = "PATH=%h/.local/bin:${pkgs.bash}/bin";
      TimeoutStartSec = 90;
      ExecStart = "${pkgs.bash}/bin/bash %h/.config/hypr/scripts/qs-calendar.sh sync";
    };
  };

  systemd.user.timers.icloud-calendar-sync = {
    Unit.Description = "Periodic calendar sync";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "15m";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.cursor-update = {
    Unit = {
      Description = "Update Cursor AppImage";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = "CURSOR_UPDATE_POLICY=newest";
      ExecStart = "%h/.local/bin/cursor-update --apply";
    };
  };

  systemd.user.timers.cursor-update = {
    Unit.Description = "Periodically update Cursor";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      AccuracySec = "5min";
      Persistent = true;
      Unit = "cursor-update.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.vscode-cursor-sync = {
    Unit.Description = "Sync VS Code and Cursor settings";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/vscode-cursor-sync --auto";
    };
  };

  systemd.user.paths.vscode-cursor-sync = {
    Unit.Description = "Watch editor settings for SSOT sync";
    Path = {
      PathModified = [
        "%h/.config/Code/User/settings.json"
        "%h/.config/Code/User/keybindings.json"
        "%h/.config/Cursor/User/settings.json"
        "%h/.config/Cursor/User/keybindings.json"
        "%h/.vscode/extensions/extensions.json"
        "%h/.cursor/extensions/extensions.json"
      ];
      Unit = "vscode-cursor-sync.service";
      TriggerLimitIntervalSec = 30;
      TriggerLimitBurst = 20;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.vscode-cursor-sync-idle = {
    Unit.Description = "Apply pending Cursor SSOT state";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/vscode-cursor-sync --apply-cursor-state";
    };
  };

  systemd.user.timers.vscode-cursor-sync-idle = {
    Unit.Description = "Apply pending Cursor SSOT state";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      AccuracySec = "15s";
      Persistent = false;
      Unit = "vscode-cursor-sync-idle.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.tmux-save = {
    Unit = {
      Description = "Save tmux session state on logout";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "%h/.config/tmux/tmux-save.sh worker-now";
      TimeoutStopSec = 45;
    };
    Install.WantedBy = [ "default.target" ];
  };
}

# Arch package name -> nixpkgs attribute, a NixOS module, or an explicit gap.
# A "pkg" value that is missing from nixpkgs throws at evaluation. Gaps are
# listed, not dropped. "module:" means the NixOS module provides it.
{ lib, pkgs }:
let
  raw = {
    # --- official repo ---
    "7zip" = "p7zip";
    age = "age";
    ansible = "ansible";
    archlinux-wallpaper = "gap:Arch wallpaper set, no nixpkgs equivalent";
    asciiquarium = "asciiquarium";
    aws-cli-v2 = "awscli2";
    bandwhich = "bandwhich";
    base = "module:nixos base system";
    base-devel = "module:nixos build tools come with the package set";
    bat = "bat";
    bind = "bind";
    bluez = "module:hardware.bluetooth";
    bluez-utils = "module:hardware.bluetooth";
    bottom = "bottom";
    brightnessctl = "brightnessctl";
    btop = "btop";
    cava = "cava";
    chafa = "chafa";
    choose = "choose";
    cliphist = "cliphist";
    cmake = "cmake";
    cmatrix = "cmatrix";
    cpio = "cpio";
    cups = "module:services.printing";
    cups-pk-helper = "module:services.printing";
    ddcutil = "ddcutil";
    direnv = "direnv";
    discord = "discord";
    dive = "dive";
    docker = "module:virtualisation.docker";
    doggo = "doggo";
    dolphin = "kdePackages.dolphin";
    duf = "duf";
    dunst = "dunst";
    dust = "dust";
    evince = "evince";
    exfatprogs = "exfatprogs";
    eza = "eza";
    fastfetch = "fastfetch";
    fd = "fd";
    ffmpegthumbnailer = "ffmpegthumbnailer";
    figlet = "figlet";
    file-roller = "file-roller";
    firefox = "firefox";
    fish = "module:programs.fish";
    fzf = "fzf";
    gemini-cli = "gemini-cli";
    git = "git";
    git-delta = "delta";
    github-cli = "gh";
    glow = "glow";
    gnome-backgrounds = "gnome-backgrounds";
    gnome-keyring = "gnome-keyring";
    goverlay = "goverlay";
    go-yq = "yq-go";
    gping = "gping";
    gpu-screen-recorder-ui = "gpu-screen-recorder";
    grim = "grim";
    gst-plugin-pipewire = "module:services.pipewire";
    gum = "gum";
    helm = "kubernetes-helm";
    hexyl = "hexyl";
    htop = "htop";
    hyperfine = "hyperfine";
    hypridle = "hypridle";
    hyprland = "module:programs.hyprland";
    hyprlock = "hyprlock";
    hyprpaper = "hyprpaper";
    hyprpicker = "hyprpicker";
    hyprpolkitagent = "hyprpolkitagent";
    hyprshot = "hyprshot";
    imagemagick = "imagemagick";
    imv = "imv";
    inetutils = "inetutils";
    inxi = "inxi";
    ipcalc = "ipcalc";
    iwd = "iwd";
    jdk-openjdk = "jdk";
    k9s = "k9s";
    keychain = "keychain";
    kind = "kind";
    kitty = "kitty";
    kubectl = "kubectl";
    lact = "lact";
    lazydocker = "lazydocker";
    lazygit = "lazygit";
    less = "less";
    libinput-tools = "libinput";
    libpulse = "libpulseaudio";
    libreoffice-fresh = "libreoffice";
    linux-firmware = "module:NixOS hardware.firmware";
    lolcat = "lolcat";
    loupe = "loupe";
    lsof = "lsof";
    mangohud = "mangohud";
    meson = "meson";
    miller = "miller";
    mpv = "mpv";
    nano = "nano";
    nautilus = "nautilus";
    nautilus-image-converter = "gap:removed from nixpkgs; Nautilus resize/rotate extension is gone";
    neovim = "neovim";
    networkmanager = "module:networking.networkmanager";
    network-manager-applet = "networkmanagerapplet";
    nodejs = "nodejs";
    npm = "module:nodejs bundles npm";
    nvtop = "nvtopPackages.nvidia";
    nwg-displays = "nwg-displays";
    nwg-look = "nwg-look";
    obsidian = "obsidian";
    obs-studio = "obs-studio";
    onefetch = "onefetch";
    openai-codex = "codex";
    opencode = "opencode";
    openrgb = "openrgb";
    otf-font-awesome = "font-awesome";
    ouch = "ouch";
    packer = "packer";
    pacman-contrib = "gap:pacman-only, unused on NixOS";
    papirus-icon-theme = "papirus-icon-theme";
    pastel = "pastel";
    pipewire = "module:services.pipewire";
    pipewire-alsa = "module:services.pipewire.alsa";
    pipewire-jack = "module:services.pipewire.jack";
    pipewire-pulse = "module:services.pipewire.pulse";
    pkgfile = "gap:pacman file index, unused on NixOS";
    pnpm = "pnpm";
    polkit-kde-agent = "module:hyprpolkitagent replaces it";
    powerline-fonts = "powerline-fonts";
    pre-commit = "pre-commit";
    procs = "procs";
    python-lz4 = "python3Packages.lz4";
    python-pynvim = "python3Packages.pynvim";
    python-websocket-client = "python3Packages.websocket-client";
    qalculate-gtk = "qalculate-gtk";
    qt5-wayland = "qt5.qtwayland";
    qt6-wayland = "qt6.qtwayland";
    quickshell = "quickshell";
    qwen-code = "qwen-code";
    resvg = "resvg";
    sassc = "sassc";
    sd = "sd";
    sddm = "module:services.displayManager.sddm";
    shellcheck = "shellcheck";
    slurp = "slurp";
    smartmontools = "smartmontools";
    sof-firmware = "sof-firmware";
    sops = "sops";
    speedtest-cli = "speedtest-cli";
    spotify-launcher = "spotify";
    starship = "starship";
    stow = "stow";
    s-tui = "s-tui";
    sudo = "module:security.sudo";
    swappy = "swappy";
    swaync = "swaynotificationcenter";
    system-config-printer = "system-config-printer";
    tealdeer = "tealdeer";
    telegram-desktop = "telegram-desktop";
    terraform = "terraform";
    tesseract = "module:overridden in system.nix with eng and rus";
    tesseract-data-eng = "module:overridden in system.nix with eng and rus";
    tesseract-data-rus = "module:overridden in system.nix with eng and rus";
    thunar = "thunar";
    thunderbird = "thunderbird";
    tmux = "tmux";
    toilet = "toilet";
    tokei = "tokei";
    traceroute = "traceroute";
    translate-shell = "translate-shell";
    trash-cli = "trash-cli";
    tree = "tree";
    ttf-dejavu = "dejavu_fonts";
    ttf-jetbrains-mono = "jetbrains-mono";
    unrar = "unrar";
    unzip = "unzip";
    usbutils = "usbutils";
    uwsm = "uwsm";
    vim = "vim";
    waybar = "waybar";
    wget = "wget";
    wireless_tools = "wirelesstools";
    wireplumber = "module:services.pipewire.wireplumber";
    woff2-font-awesome = "font-awesome";
    wofi = "wofi";
    wpa_supplicant = "module:NetworkManager";
    wtype = "wtype";
    xdg-desktop-portal-hyprland = "module:programs.hyprland";
    xdg-utils = "xdg-utils";
    xh = "xh";
    xorg-server = "xorg-server";
    xorg-xinit = "xinit";
    yazi = "yazi";
    zellij = "zellij";
    zip = "zip";
    zoxide = "zoxide";
    zram-generator = "module:zramSwap";

    # --- required by the rice scripts ---
    awww = "awww";
    ffmpeg = "ffmpeg";
    jq = "jq";
    khal = "khal";
    libnotify = "libnotify";
    matugen = "matugen";
    "otf-atkinson hyperlegiblemono-nerd" = "module:nix/clients.nix atkinsonMonoNerd (nerd-fonts v3.5.1)";
    playerctl = "playerctl";
    python-pillow = "python3Packages.pillow";
    ripgrep = "ripgrep";
    socat = "socat";
    sqlite = "sqlite";
    uv = "uv";
    vdirsyncer = "vdirsyncer";
    waypaper = "waypaper";
    wl-clipboard = "wl-clipboard";

    # --- AUR ---
    apple_cursor = "module:nix/themes.nix appleCursor (ful1e5/apple_cursor)";
    apple_hyprcursor = "module:nix/themes.nix appleHyprcursor (6ooker/apple_hyprcursor)";
    cbonsai = "cbonsai";
    claude-desktop = "gap:unpackaged desktop client";
    devin-desktop = "devin-desktop";
    docker-desktop = "module:virtualisation.docker (engine, not Docker Desktop)";
    google-chrome = "google-chrome";
    gromit-mpx = "gromit-mpx";
    hyprliquid = "module:nix/clients.nix hyprliquid (zaregototsukai/hyprliquid)";
    jetbrains-toolbox = "jetbrains-toolbox";
    kanata-bin = "kanata";
    kontur-talk = "gap:unpackaged vendor client";
    openrgb-plugin-effects = "openrgb-plugin-effects";
    openrgb-plugin-hardware-sync = "module:nix/clients.nix openrgbHardwareSync (release_1.0)";
    openrgb-plugin-visual-map = "module:nix/clients.nix openrgbVisualMap (release_1.0)";
    peaclock = "peaclock";
    "pipes.sh" = "pipes";
    spicetify-bin = "spicetify-cli";
    spokenly = "gap:unpackaged";
    tty-clock = "tty-clock";
    vibepanel-bin = "module:flake input prankstr/vibepanel v0.17.2";
    visual-studio-code-bin = "vscode";
    voxtype-bin = "voxtype";
    windscribe-cli-v2-bin = "gap:unpackaged VPN client";
    yandex-browser = "gap:unpackaged";
    yay = "gap:AUR helper, unused on NixOS";
    zen-browser-bin = "module:nix/clients.nix zen (zen-browser/desktop 1.24.2b)";
    zoom = "zoom-us";

    # --- this machine's hardware ---
    intel-ucode = "module:hardware.cpu.intel.updateMicrocode";
    egl-wayland = "module:hardware.nvidia";
    libva-nvidia-driver = "module:hardware.nvidia";
    nvidia-open = "module:hardware.nvidia.open";
    nvidia-settings = "module:hardware.nvidia.nvidiaSettings";
    nvidia-utils = "module:hardware.nvidia";
    vulkan-nouveau = "gap:conflicts with the NVIDIA driver";
    xf86-video-nouveau = "gap:conflicts with the NVIDIA driver";
    breeze-plymouth = "module:systemd-boot, plymouth theme not carried over";
    efibootmgr = "module:boot.loader.systemd-boot";
    grub = "module:boot.loader.systemd-boot";
    grub-theme-vimix = "module:boot.loader.systemd-boot";
    linux = "module:boot.kernelPackages";
    linux-headers = "module:boot.kernelPackages";
    plymouth = "module:not enabled; systemd-boot shows the loader instead";
  };

  isPkg = v: !(lib.hasPrefix "module:" v || lib.hasPrefix "gap:" v);

  hasPath = path:
    let
      parts = lib.splitString "." path;
      go = i: val:
        if i == builtins.length parts then true
        else if val ? ${builtins.elemAt parts i} then go (i + 1) (builtins.getAttr (builtins.elemAt parts i) val)
        else false;
    in
    go 0 pkgs;

  resolvePath = path:
    lib.foldl' (acc: part: builtins.getAttr part acc) pkgs (lib.splitString "." path);

  pkgNames = lib.filter (n: isPkg raw.${n}) (lib.attrNames raw);
in
{
  gaps = lib.filterAttrs (_: v: lib.hasPrefix "gap:" v) raw;
  modules = lib.filterAttrs (_: v: lib.hasPrefix "module:" v) raw;
  packages = lib.unique (map (name:
    let nixName = raw.${name}; in
    if hasPath nixName then resolvePath nixName
    else throw "nixpkgs has no `${nixName}` for Arch package `${name}`. Map it or mark it gap: in nix/package-map.nix"
  ) pkgNames);
}

# Public clients the pinned nixpkgs does not ship.
# Zen is the MPL upstream tarball. hyprliquid is the BSD Hyprland plugin.
# The Atkinson Mono nerd font is the ryanoasis release for the jammed
# package-list line.
{ pkgs }:
{
  zen = pkgs.stdenv.mkDerivation {
    pname = "zen-browser";
    version = "1.24.2b";
    src = pkgs.fetchurl {
      url = "https://github.com/zen-browser/desktop/releases/download/1.24.2b/zen.linux-x86_64.tar.xz";
      hash = "sha256-vPfkMWDs/l8plT7SqYTnqAKKWPLsDjEU02u5BNX1zoA=";
    };
    sourceRoot = "zen";
    nativeBuildInputs = [
      pkgs.wrapGAppsHook3
      pkgs.autoPatchelfHook
      pkgs.patchelfUnstable
    ];
    buildInputs = [
      pkgs.gtk3
      pkgs.adwaita-icon-theme
      pkgs.alsa-lib
      pkgs.dbus-glib
      pkgs.libXtst
    ];
    runtimeDependencies = [
      pkgs.curl
      pkgs.libva.out
      pkgs.pciutils
    ];
    appendRunpaths = [ "${pkgs.pipewire}/lib" ];
    # Firefox relocates itself from a fixed offset. A normal patchelf
    # rewrite corrupts that.
    patchelfFlags = [ "--no-clobber-old-sections" ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/zen-browser" "$out/bin"
      cp -a . "$out/lib/zen-browser"
      ln -s "$out/lib/zen-browser/zen-bin" "$out/bin/zen-bin"
      runHook postInstall
    '';
    meta.mainProgram = "zen-bin";
  };

  hyprliquid = pkgs.hyprland.stdenv.mkDerivation {
    pname = "hyprliquid";
    version = "0.3.0";
    src = pkgs.fetchFromGitHub {
      owner = "zaregototsukai";
      repo = "hyprliquid";
      rev = "3130471b3eebe1c2012ea21d3452bf6703f940c1";
      hash = "sha256-c/zXDShNmNzgguvi0fGtrVQrDTyL5Q5K8so6ur7TbWw=";
    };
    nativeBuildInputs = [
      pkgs.cmake
      pkgs.pkg-config
    ];
    buildInputs = [
      pkgs.hyprland.dev
      pkgs.stb
      pkgs.systemd
    ] ++ pkgs.hyprland.buildInputs;
  };

  atkinsonMonoNerd = pkgs.runCommand "atkinson-hyperlegible-mono-nerd-3.5.1" {
    src = pkgs.fetchurl {
      url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/AtkinsonHyperlegibleMono.tar.xz";
      hash = "sha256-oP0T60j/LHUi9lI2nSrdTShZA/YAUlxrtyvlzyRI71U=";
    };
  } ''
    mkdir -p "$out/share/fonts/opentype"
    tar -xJf "$src" -C "$out/share/fonts/opentype"
    test -f "$out/share/fonts/opentype/AtkynsonMonoNerdFont-Regular.otf"
  '';
}

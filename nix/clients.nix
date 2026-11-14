# Public clients the pinned nixpkgs does not ship.
# Zen is the MPL upstream tarball. hyprliquid is the BSD Hyprland plugin.
# The Atkinson Mono nerd font is the ryanoasis release for the jammed
# package-list line.
{ pkgs }:
{
  zen = pkgs.stdenv.mkDerivation rec {
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
    desktopFile = pkgs.fetchurl {
      url = "https://github.com/zen-browser/desktop/raw/refs/tags/1.24.2b/build/AppDir/zen.desktop";
      hash = "sha256-P61k0RwfvAFcAkxbNRf9v6svVYW9KtCxw5qAWuD/eRo=";
    };
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/zen-browser" "$out/bin" "$out/share/applications"
      cp -a . "$out/lib/zen-browser"
      # The upstream entry runs `zen`. The tarball ships that name and zen-bin
      # as the same executable. The rice launcher looks up zen-bin.
      ln -s "$out/lib/zen-browser/zen" "$out/bin/zen"
      ln -s "$out/lib/zen-browser/zen-bin" "$out/bin/zen-bin"
      cp ${desktopFile} "$out/share/applications/zen.desktop"
      for size in 16 32 48 64 128; do
        mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
        cp "browser/chrome/icons/default/default''${size}.png" \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/zen.png"
      done
      test -f "$out/share/applications/zen.desktop"
      grep -q '^Exec=zen %u$' "$out/share/applications/zen.desktop"
      test -f "$out/share/icons/hicolor/128x128/apps/zen.png"
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

  # Same shape as nixpkgs openrgb-plugin-effects: qmake plugin, .so in
  # lib/openrgb/plugins. Public release_1.0 tags.
  openrgbHardwareSync = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "openrgb-plugin-hardware-sync";
    version = "1.0";
    src = pkgs.fetchFromGitLab {
      owner = "OpenRGBDevelopers";
      repo = "OpenRGBHardwareSyncPlugin";
      tag = "release_${finalAttrs.version}";
      hash = "sha256-aqcx3E3t7WEvOPtS7nfvn9jUURE5MhRcL6+HrkZIY6o=";
      fetchSubmodules = true;
    };
    qmakeFlags = [
      "CONFIG+=link_pkgconfig"
      "QT_TOOL.lrelease.binary=${pkgs.lib.getDev pkgs.qt6Packages.qttools}/bin/lrelease"
    ];
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.qt6Packages.wrapQtAppsHook
      pkgs.qt6Packages.qmake
    ];
    buildInputs = [
      pkgs.qt6Packages.qtbase
      pkgs.qt6Packages.qt5compat
      pkgs.glib
      pkgs.libgtop
      pkgs.lm_sensors
    ];
  });

  openrgbVisualMap = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "openrgb-plugin-visual-map";
    version = "1.0";
    src = pkgs.fetchFromGitLab {
      owner = "OpenRGBDevelopers";
      repo = "OpenRGBVisualMapPlugin";
      tag = "release_${finalAttrs.version}";
      hash = "sha256-3gkshCvoOfneLO8IlXRGAxie+r6BYH+Tmrz6A5vkZgo=";
      fetchSubmodules = true;
    };
    qmakeFlags = [
      "CONFIG+=link_pkgconfig"
      "QT_TOOL.lrelease.binary=${pkgs.lib.getDev pkgs.qt6Packages.qttools}/bin/lrelease"
    ];
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.qt6Packages.wrapQtAppsHook
      pkgs.qt6Packages.qmake
    ];
    buildInputs = [
      pkgs.qt6Packages.qtbase
      pkgs.qt6Packages.qt5compat
    ];
  });

  # Public release of the Arch wallpaper set. The rice does not theme these;
  # they are the upstream files the Arch package installs.
  archlinuxWallpaper = pkgs.stdenv.mkDerivation {
    pname = "archlinux-wallpaper";
    version = "1.6.1";
    src = pkgs.fetchurl {
      url = "https://github.com/xyproto/archlinux-wallpaper/releases/download/1.6.1/archlinux-wallpaper-1.6.1.tar.gz";
      hash = "sha256-61D1/5ckoAtL0PBNFBJ6YhvkJE1fYGUJcoMkZoTAhMA=";
    };
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/backgrounds/archlinux" "$out/share/gnome-background-properties"
      cp -a archlinux.stw img/. "$out/share/backgrounds/archlinux/"
      cp arch-backgrounds.xml "$out/share/gnome-background-properties/"
      test -f "$out/share/backgrounds/archlinux/archlinux.stw"
      runHook postInstall
    '';
  };

  # Corey Berla's public 0.4.0 port of the archived Nautilus extension.
  nautilusImageConverter = pkgs.stdenv.mkDerivation {
    pname = "nautilus-image-converter";
    version = "0.4.0";
    src = pkgs.fetchFromGitLab {
      domain = "gitlab.gnome.org";
      owner = "coreyberla";
      repo = "nautilus-image-converter";
      tag = "0.4.0";
      hash = "sha256-o3/l/juQ3wl2JRj606+z/hsprPqt5iz/0I5BrpKrK5s=";
    };
    postPatch = ''
      substituteInPlace meson.build \
        --replace-fail \
          "nautilus_extension_dir = libnautilus_extension.get_pkgconfig_variable('extensiondir')" \
          "nautilus_extension_dir = get_option('prefix') / get_option('libdir') / 'nautilus' / 'extensions-4'"
      # Upstream fr.po has an empty charset. msgfmt in gettext 1.0 rejects it.
      # Same two-line fix as Debian 0.4.0-3.
      substituteInPlace po/fr.po \
        --replace-fail 'Content-Type: text/plain; charset=' 'Content-Type: text/plain; charset=UTF-8' \
        --replace-fail 'Content-Transfer-Encoding: ' 'Content-Transfer-Encoding: 8bit'
    '';
    nativeBuildInputs = [
      pkgs.meson
      pkgs.ninja
      pkgs.pkg-config
      pkgs.glib
    ];
    buildInputs = [
      pkgs.gtk4
      pkgs.glib
      pkgs.nautilus
    ];
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

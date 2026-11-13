# Public theme files the rice names. Not personal config.
# Graphite-Dark is vinceliuice/Graphite-gtk-theme (nixpkgs dropped the
# package when gtk-engine-murrine left). GTK 3/4 do not need that engine.
# macOS is ful1e5/apple_cursor. macOS-hypr is 6ooker/apple_hyprcursor.
{ pkgs }:
{
  graphite = pkgs.stdenv.mkDerivation {
    pname = "graphite-gtk-theme";
    version = "2026-08-24";
    src = pkgs.fetchFromGitHub {
      owner = "vinceliuice";
      repo = "Graphite-gtk-theme";
      rev = "364173f47407164948788e4abb5e2eb46600f71a";
      hash = "sha256-j9T66mQfLij1OMBSnlwVM4t1mL2wigUKQ6yqdSRlaCA=";
    };
    nativeBuildInputs = [ pkgs.sassc ];
    # The installer edits sass in the tree, and the Nix source is read-only.
    installPhase = ''
      runHook preInstall
      cp -a . "$NIX_BUILD_TOP/src"
      chmod -R u+w "$NIX_BUILD_TOP/src"
      cd "$NIX_BUILD_TOP/src"
      # Nix exports `name` as the derivation name, which this script treats
      # as the theme name. HOME is not writable; the switcher app is not
      # part of the rice and is left in the build home.
      export HOME="$NIX_BUILD_TOP/home"
      mkdir -p "$HOME"
      bash ./install.sh --dest "$out/share/themes" --name Graphite --color dark
      test -f "$out/share/themes/Graphite-Dark/gtk-3.0/gtk.css"
      test -f "$out/share/themes/Graphite-Dark/gtk-4.0/gtk.css"
      runHook postInstall
    '';
  };

  appleCursor = pkgs.runCommand "apple-cursor-2.0.1" {
    src = pkgs.fetchurl {
      url = "https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz";
      hash = "sha256-nG5eE7BozlGp6QqavWziMux9JdTOsFqorHbvu5nHZ2I=";
    };
  } ''
    mkdir -p "$out/share/icons"
    tar -xJf "$src" -C "$out/share/icons"
    test -f "$out/share/icons/macOS/index.theme"
    test -d "$out/share/icons/macOS/cursors"
  '';

  appleHyprcursor = pkgs.runCommand "apple-hyprcursor-0.1" {
    src = pkgs.fetchurl {
      url = "https://github.com/6ooker/apple_hyprcursor/releases/download/0.1/macOS-hypr.tar.xz";
      hash = "sha256-XogJtUxzQbqzG6EiEUoEd01r65ZzqZHm4Sllq1gGduI=";
    };
  } ''
    mkdir -p "$out/share/icons"
    tar -xJf "$src" -C "$out/share/icons"
    test -f "$out/share/icons/macOS-hypr/manifest.hl"
    test -d "$out/share/icons/macOS-hypr/hyprcursors"
  '';
}

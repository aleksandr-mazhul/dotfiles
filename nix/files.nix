# Stow packages -> home-manager file entries. systemd units are declared in
# home.nix because several of them call /usr/bin, which does not exist on NixOS.
# .local/bin is merged across packages (bin and kanata both ship scripts).
{ lib }:
let
  repo = ../.;
  stow = [
    "bin" "entropy" "fastfetch" "fish" "git" "gtk" "herdr" "hypr" "kanata"
    "kitty" "matugen" "misc" "nvim" "nwg-look" "obs" "quickshell" "starship"
    "theme" "tmux" "vibepanel" "voxtype" "vscode" "waybar" "waypaper" "wofi"
    "x11" "xsettingsd" "yazi" "zellij" "zen"
  ];

  names = path:
    if builtins.pathExists path then
      lib.filter (n: n != "__pycache__" && n != ".stow-local-ignore") (builtins.attrNames (builtins.readDir path))
    else [ ];

  children = pkg: rel:
    let dir = repo + "/${pkg}/${rel}"; in
    map (n: {
      target = "${rel}/${n}";
      source = dir + "/${n}";
    }) (names dir);

  dotfilesAtRoot = pkg:
    map (n: {
      target = n;
      source = repo + "/${pkg}/${n}";
    }) (lib.filter (n: lib.hasPrefix "." n && n != ".config" && n != ".local") (names (repo + "/${pkg}")));

  entries =
    lib.concatMap (pkg:
      children pkg ".config"
      ++ children pkg ".local/share"
      ++ dotfilesAtRoot pkg
    ) stow
    ++ lib.concatMap (pkg: children pkg ".local/bin") stow;

  withoutSystemd = lib.filter (e: !(lib.hasPrefix ".config/systemd" e.target)) entries;
in
lib.foldl' (acc: e:
  if acc ? ${e.target} then
    throw "two files claim ~/${e.target}"
  else
    acc // { ${e.target} = e; }
) { } withoutSystemd

#!/usr/bin/env bash
set -uo pipefail
export SUDO_ASKPASS="$HOME/.local/bin/sudo-askpass-gtk.py"
export SUDO_ASKPASS_REQUIRE=force

echo
echo "=============================================="
echo "  Полное обновление + GloView"
echo "=============================================="
echo " Пароль спросит GUI-окно."
echo " Раскладка принудительно English (US)."
echo

# Force US layout
hyprctl switchxkblayout "ergohaven-k:03-v3/v4" 0 >/dev/null 2>&1 || true

if command -v hyprpolkitagent >/dev/null && ! pgrep -x hyprpolkitagent >/dev/null; then
  nohup hyprpolkitagent >/tmp/hyprpolkitagent.log 2>&1 &
  sleep 0.5
fi

run_sudo() {
  local n=1
  while true; do
    hyprctl switchxkblayout "ergohaven-k:03-v3/v4" 0 >/dev/null 2>&1 || true
    if sudo -A "$@"; then
      return 0
    fi
    echo
    echo " Не приняли (попытка $n)."
    echo " Проверь: пароль верный? Caps Lock выключен?"
    echo " Если много ошибок — подожди 10 мин (faillock)."
    echo
    n=$((n + 1))
    if (( n > 4 )); then
      read -r -p "Enter — выход "
      exit 1
    fi
  done
}

echo ">>> 1/6 full system upgrade"
run_sudo pacman -Syu --noconfirm

echo ">>> 2/6 AUR (yay)"
if command -v yay >/dev/null; then
  yay -Syu --noconfirm --sudoloop || echo "yay: были предупреждения"
fi

echo ">>> 3/6 hyprpm cache perms"
run_sudo mkdir -p /var/cache/hyprpm
run_sudo chown -R "$USER:$USER" /var/cache/hyprpm

echo ">>> 4/6 hyprpm + gloview"
hyprpm update || true
hyprpm disable hyprexpo 2>/dev/null || true
hyprpm add https://github.com/fedsfarm/gloview || true
hyprpm enable gloview || true
hyprpm reload -n || true

echo ">>> 5/6 config → gloview"
CONF="$HOME/.config/hypr/hyprland.conf"
sed -i 's|^source = ~/.config/hypr/hyprexpo.conf|# source = ~/.config/hypr/hyprexpo.conf|' "$CONF"
sed -i 's|^# source = ~/.config/hypr/gloview.conf|source = ~/.config/hypr/gloview.conf|' "$CONF"
if ! grep -qE '^[[:space:]]*source = ~/.config/hypr/gloview.conf' "$CONF"; then
  echo 'source = ~/.config/hypr/gloview.conf' >> "$CONF"
fi

echo ">>> 6/6 versions"
pacman -Q hyprland hyprutils hyprgraphics aquamarine 2>/dev/null || true
hyprpm list || true

echo
echo "Готово. Перелогинься в Hyprland (или reboot), затем Ctrl+↑"
read -r -p "Enter — выход "

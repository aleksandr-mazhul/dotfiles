#!/usr/bin/env bash
set -uo pipefail
echo
echo "=========================================="
echo "  Mission Control (hyprexpo) — установка"
echo "=========================================="
echo
echo " ВАЖНО: раскладка EN перед паролем sudo."
echo

run_sudo() {
  local n=1
  while true; do
    if "$@"; then
      return 0
    fi
    echo
    echo " sudo не принял пароль (попытка $n)."
    echo " Проверь раскладку EN и попробуй ещё раз."
    echo
    n=$((n + 1))
    if (( n > 5 )); then
      echo " Слишком много неудач. Напиши в чат."
      read -r -p " Enter — выход "
      exit 1
    fi
  done
}

echo ">>> 1/5 зависимости"
run_sudo sudo pacman -S --needed --noconfirm cpio cmake hyprpolkitagent

echo ">>> 2/5 polkit agent"
if ! pgrep -x hyprpolkitagent >/dev/null; then
  nohup hyprpolkitagent >/tmp/hyprpolkitagent.log 2>&1 &
  sleep 1
fi

echo ">>> 3/5 кэш hyprpm"
run_sudo sudo mkdir -p /var/cache/hyprpm
run_sudo sudo chown -R "$USER:$USER" /var/cache/hyprpm

echo ">>> 4/5 hyprpm update + hyprexpo (сборка ~1–3 мин)"
hyprpm update
hyprpm add https://github.com/sandwichfarm/hyprexpo || true
hyprpm enable hyprexpo
hyprpm reload -n || true

echo ">>> 5/5 конфиг + проверка"
# enable source if commented
sed -i 's|^# source = ~/.config/hypr/hyprexpo.conf|source = ~/.config/hypr/hyprexpo.conf|' \
  "$HOME/.config/hypr/hyprland.conf" || true
if ! grep -qE '^[[:space:]]*source = ~/.config/hypr/hyprexpo.conf' "$HOME/.config/hypr/hyprland.conf"; then
  if ! grep -q 'hyprexpo.conf' "$HOME/.config/hypr/hyprland.conf"; then
    echo 'source = ~/.config/hypr/hyprexpo.conf' >> "$HOME/.config/hypr/hyprland.conf"
  fi
fi

hyprctl reload
sleep 1
hyprpm reload -n || true
sleep 1

echo
hyprpm list
echo
hyprctl plugin list || true
echo
if hyprctl plugin list 2>&1 | grep -qi hyprexpo; then
  echo "OK: hyprexpo загружен. Жми Ctrl+↑"
else
  echo "Плагин не в hyprctl — смотри вывод выше."
fi
echo
echo "Готово. Окно можно закрыть."
read -r -p "Enter — выход "

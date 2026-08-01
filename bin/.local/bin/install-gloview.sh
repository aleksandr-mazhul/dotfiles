#!/usr/bin/env bash
set -uo pipefail
echo
echo "=========================================="
echo "  GloView — установка"
echo "=========================================="
echo " Раскладка EN для пароля sudo (если спросит)."
echo

hyprpm disable hyprexpo 2>/dev/null || true

echo ">>> hyprpm add gloview"
hyprpm add https://github.com/fedsfarm/gloview || true

echo ">>> enable + reload"
hyprpm enable gloview
hyprpm reload -n || true

sleep 1
hyprctl reload
sleep 1

echo
hyprpm list
echo
hyprctl plugin list || true
echo
if hyprctl plugin list 2>&1 | grep -qi gloview; then
  echo "OK: gloview загружен. Жми Ctrl+↑"
else
  echo "Не загрузился — смотри вывод выше."
fi
echo
read -r -p "Enter — выход "

# Dotfiles — Hyprland rice (Arch Linux)

Персональная среда на **Arch + Hyprland**: Mac-like ввод (Kanata), динамическая палитра с обоев (SSOT), Quickshell-бар, Kitty/Fish/Tmux, Zen Browser и полный инвентарь пакетов для восстановления с нуля.

Управляется через **GNU Stow**. Секреты (логины, SSH, токены) в репозиторий не входят — см. [RESTORE.md](RESTORE.md).

---

## Быстрый старт после переустановки

```bash
git clone git@github.com:aleksandr-mazhul/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

| Вариант | Что делает |
| --- | --- |
| `./bootstrap.sh` | Все пакеты (`repo.txt` + `aur.txt`) → restow → kanata → fish → тема → SDDM |
| `./bootstrap.sh --rice` | Урезанный rice-набор |
| `./bootstrap.sh --configs` | Только конфиги/сервисы/тема (пакеты уже стоят) |

Обои (опционально):

```bash
BOOTSTRAP_WALLPAPER=~/Pictures/Wallpapers/nature/foo.jpg ./bootstrap.sh
```

Подробный scope восстановления: **[RESTORE.md](RESTORE.md)**.  
Списки приложений: **[packages/](packages/)**.  
Хоткеи (Hypr/kitty/nvim/kanata): **[KEYBINDS.md](KEYBINDS.md)**.  
Правила для AI-агентов: **[AGENTS.md](AGENTS.md)**.

---

## Архитектура

```text
Wallpaper
   │
   ▼
theme-extract → theme-match → theme-build → palette.toml (SSOT)
                                              │
                                         theme-render
                                              │
    ┌───────────┬──────────┬─────────┬────────┼────────┬──────────┐
    ▼           ▼          ▼         ▼        ▼        ▼          ▼
  Kitty      Hyprland   Quickshell  GTK    nvim     tmux/starship  …
  Zen/Vimium  lock      wofi/yazi   bat    btop     cava/glow/…
```

Обычный цикл после смены обоев:

```bash
apply-wallpaper-theme ~/Pictures/Wallpapers/….jpg
exec fish   # обновить fish-обёртки (cbonsai, pipes, gum, …)
```

Шаблоны и детали пайплайна: [theme/.config/theme/README.md](theme/.config/theme/README.md).

---

## Структура репозитория

| Путь | Назначение |
| --- | --- |
| `hypr/` | Hyprland (Lua): окна, binds, rules, lock, скрипты |
| `kanata/` | Home-row mods + remaps, user systemd unit |
| `quickshell/` | Бар / лаунчер / календарь / уведомления / clipboard (QS rice) |
| `kitty/` | Терминал + цвета/вкладки из SSOT |
| `fish/` | Shell, fzf/rice theme snippets |
| `tmux/` | Сессии, continuum/resurrect, status из SSOT |
| `nvim/` | LazyVim + palette bridge |
| `theme/` | `harmonies.toml`, templates, SSOT docs |
| `bin/` | `theme-*`, `apply-wallpaper-theme`, `zen-browser`, helpers |
| `zen/` | Keyboard shortcuts, `user.js`, Vimium mirror |
| `starship/`, `yazi/`, `gtk/`, `wofi/`, `waypaper/` | CLI/UI consumers |
| `obs/` | Сцены/профили (без websocket password) |
| `sddm/` | Adaptive login theme (`sddm/install.sh`) |
| `packages/` | Инвентарь pacman/AUR + install/export |
| `bootstrap.sh` | Полное восстановление одной командой |
| `restow.sh` | Переустановка всех Stow-пакетов в `$HOME` |

Применить только конфиги (пакеты уже установлены):

```bash
./restow.sh
```

---

## Ключевые компоненты

### Hyprland (`hypr/`)

Конфиг на **Lua** (`hyprland.lua`, `binds.lua`, `rules.lua`), не классический `hyprland.conf`.

- **Модификаторы:** `ALT` = window mgmt (`mainMod`), `SUPER` = система/бар/утилиты (`secondMod`)
- Mac-like привычки: Ctrl≈Cmd в приложениях; мышиные кнопки вкладок → Kanata → `Ctrl+PgUp/Dn`
- Workspace rules для браузеров/приложений, float-правила, скрипты скриншотов/OCR/clipboard/Zoom tabs

### Kanata (`kanata/`)

- Home-row mods (Super/Alt/Ctrl/Shift)
- `Super+Shift+[ ]` → `Ctrl+Page_Up/Down` (вкладки в Zen / окна в tmux через Kitty)
- User unit: `systemctl --user enable --now kanata.service`  
  (пользователь должен быть в группе `input`)

### Quickshell rice (`quickshell/`)

Основной UI поверх Hyprland: бар, launcher, calendar, notifications, wallpaper picker, clipboard island. Цвета из `Colors.qml` (рендер SSOT).

### Kitty + Fish + Tmux + Starship

- **Kitty** — основной терминал, прозрачность, SSOT colors/tabs; `Ctrl+PgUp/Dn` → tmux prev/next window
- **Fish** — login shell, `theme-fzf` / `theme-rice` wrappers
- **Tmux** — resurrect + continuum (сейв каждые 5 мин), deep scrollback, status из SSOT chrome tokens
- **Starship** — prompt из той же палитры

### Theme SSOT (`theme/` + `bin/theme-*`)

Единый источник правды: `~/.config/theme/palette.toml`.

Рендерится в: Hypr, lock, Kitty, GTK3/4, Quickshell, Wofi, Starship, Tmux, Yazi, fzf, bat, lazygit, nvim, Herdr, Vimium, btop, cava, peaclock, glow, bottom и fish-обёртки rice-утилит.

### Zen Browser (`zen/` + `zen-browser`)

В git только:

- `zen-keyboard-shortcuts.json`
- `user.js`
- `vimium-options.json` (зеркало; CSS пишет `theme-render`)

Лаунчер `zen-browser` синхронизирует shortcuts/`user.js` в профиль и Vimium CSS до/после запуска. Полный профиль (cookies/logins) **не** коммитится.

### nvim (`nvim/`)

LazyVim-стек + `palette.lua` / `ssot-colors` под обойную гамму.

### Прочее

| Пакет | Заметка |
| --- | --- |
| `yazi/` | Файловый TUI + theme |
| `waypaper/` | Выбор обоев → theme pipeline |
| `wofi/` | Fallback launcher styles |
| `herdr/` | Доп. theming consumer |
| `obs/` | Recording/scenes для Hyprland |
| `misc/` | mimeapps, gromit-mpx, … |
| `git/` | Глобальный `.gitconfig` |
| `fastfetch/` | Fetch при старте fish |

---

## Пакеты и новые приложения

| Файл | Содержимое |
| --- | --- |
| `packages/repo.txt` | Все явные пакеты official (~197) |
| `packages/aur.txt` | AUR (~21; без `*-debug`) |
| `packages/rice-*.txt` | Курируемый rice-минимум |
| `packages/install.sh` | Установка списков |
| `packages/export.sh` | Обновить списки с текущей машины |

После установки чего-то нового:

```bash
./packages/export.sh
# или
dotfiles-register-app <pkg> [--aur] [--rice]
./restow.sh          # если добавили конфиг в Stow-пакет
# при необходимости — шаблон в theme/ + mapping в theme-render
```

Чеклист для агентов: [AGENTS.md](AGENTS.md).

---

## Типичный day-to-day

```bash
# Сменить обои и перекрасить весь стек
apply-wallpaper-theme ~/Pictures/Wallpapers/….jpg

# Только перерисовать consumers из текущего palette.toml
theme-render

# Только Vimium CSS (Zen лучше закрыть)
theme-vimium

# Переложить симлинки после правок в репо
./restow.sh
```

Полезные rice-команды (после `exec fish`): `cava`, `btop`, `btm`, `peaclock`, `cbonsai -l`, `tty-clock`, `pipes.sh`, `glow README.md`.

---

## Что не восстанавливается из git

| Данные | Причина |
| --- | --- |
| Профиль Zen / пароли браузера | секреты и PII |
| SSH / GPG / `gh` tokens | секреты |
| Discord, Spotify, JetBrains, VS Code data | тяжёлые и machine-local |
| Пароль OBS websocket | gitignored |
| Библиотека обоев | копировать отдельно в `~/Pictures/Wallpapers` |

После `bootstrap.sh`: положить обои и ключи, `gh auth login`, один раз открыть Zen через `zen-browser`.

---

## Требования

- Arch Linux (или совместимый pacman)
- Сеть + `sudo` (для пакетов и SDDM)
- Реальный терминал для пароля (`yay` / `sudo`)
- Для Kanata: группа `input`, затем re-login

---

## Документация

| Документ | О чём |
| --- | --- |
| [RESTORE.md](RESTORE.md) | Scope bootstrap: что входит / что нет |
| [packages/README.md](packages/README.md) | Инвентарь и install/export |
| [theme/.../README.md](theme/.config/theme/README.md) | SSOT pipeline и consumers |
| [AGENTS.md](AGENTS.md) | Как агентам добавлять приложения |
| [.cursor/rules/](.cursor/rules/) | Cursor rules для этого репо |

---

## Лицензия / использование

Личный rice. Можно форкать и адаптировать; пути вроде `/home/stranger` и профиль Zen захардкожены под эту машину — при переносе проверьте `ZEN_PROFILE`, `restow.sh` target и списки пакетов.

# Dotfiles — Hyprland rice (Arch Linux)

Персональная среда на **Arch + Hyprland**: Mac-like ввод (Kanata), динамическая палитра с обоев (SSOT), Quickshell UI, Kitty/Fish/Tmux, Zen Browser и полный инвентарь пакетов для восстановления с нуля.

Управляется через **[GNU Stow](https://www.gnu.org/software/stow/)**. Секреты в репозиторий не входят.

| Документ | Зачем открыть |
| --- | --- |
| **[KEYBINDS.md](KEYBINDS.md)** | Все хоткеи: Hyprland, kitty, nvim, kanata |
| **[RESTORE.md](RESTORE.md)** | Что входит в bootstrap и что нет |
| **[AGENTS.md](AGENTS.md)** | Чеклист для AI-агентов при новых приложениях |
| **[packages/](packages/)** | Списки pacman / AUR |
| **[theme/…/README.md](theme/.config/theme/README.md)** | Пайплайн цветов (SSOT) |

---

## Быстрый старт

```bash
git clone git@github.com:Aleksandr-Mazhul/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

| Команда | Что делает |
| --- | --- |
| `./bootstrap.sh` | Пакеты (`repo.txt` + `aur.txt`) → restow → kanata → fish → тема → SDDM |
| `./bootstrap.sh --rice` | Урезанный rice-набор (`rice-*.txt`) |
| `./bootstrap.sh --configs` | Только конфиги / сервисы / тема (пакеты уже стоят) |
| `./restow.sh` | Переустановить Stow-симлинки в `$HOME` |

Обои при bootstrap (опционально):

```bash
BOOTSTRAP_WALLPAPER=~/Pictures/Wallpapers/nature/foo.jpg ./bootstrap.sh
```

После установки: скопировать обои и ключи, `gh auth login`, один раз открыть Zen через `zen-browser`, `exec fish`.

---

## Архитектура темы (SSOT)

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

После смены обоев:

```bash
apply-wallpaper-theme ~/Pictures/Wallpapers/….jpg
exec fish   # обновить fish-обёртки (cbonsai, pipes, gum, …)
```

Только перерисовать consumers из текущего `palette.toml`: `theme-render`.

---

## Карта репозитория

Каждый каталог ниже (кроме служебных) — **Stow-пакет**:  
`<pkg>/.config/...` → `~/.config/...`, `<pkg>/.local/...` → `~/.local/...`.

### Ядро рабочего стола

| Пакет | Назначение |
| --- | --- |
| [`hypr/`](hypr/) | Hyprland **Lua**: окна, binds, rules, monitors, hyprlock, скрипты (screenshot, OCR, clipboard, Nautilus Mac-binds, Zoom tabs) |
| [`kanata/`](kanata/) | Home-row mods + remaps; user systemd unit |
| [`quickshell/`](quickshell/) | Rice UI: бар, launcher, clipboard, wallpaper, VPN, calendar, notifications, design-system (`ds/`), vim-engine |
| [`sddm/`](sddm/) | Adaptive login theme (`sddm/install.sh`) |
| [`waybar/`](waybar/) | Legacy/fallback bar config (основной бар — Quickshell) |
| [`vibepanel/`](vibepanel/) | Legacy panel config (исторический; UI ушёл в Quickshell) |

### Терминал и shell

| Пакет | Назначение |
| --- | --- |
| [`kitty/`](kitty/) | Основной терминал; SSOT colors/tabs; Mac-like clipboard (`Ctrl+C/V`, `Super+C` = interrupt) |
| [`fish/`](fish/) | Login shell, fzf/rice theme snippets |
| [`tmux/`](tmux/) | Resurrect + continuum, status из SSOT |
| [`starship/`](starship/) | Prompt из той же палитры |
| [`nvim/`](nvim/) | LazyVim + `palette.lua` / SSOT colors |
| [`yazi/`](yazi/) | Файловый TUI + theme + плагины |
| [`fastfetch/`](fastfetch/) | Fetch при старте fish |

### Тема и внешний вид

| Пакет | Назначение |
| --- | --- |
| [`theme/`](theme/) | `harmonies.toml`, templates, SSOT docs |
| [`bin/`](bin/) | `theme-*`, `apply-wallpaper-theme`, `zen-browser`, helpers |
| [`matugen/`](matugen/) | Material/wallpaper color helpers (рядом с SSOT) |
| [`gtk/`](gtk/) | GTK 3/4 CSS (consumers темы) |
| [`wofi/`](wofi/) | Fallback launcher styles |
| [`waypaper/`](waypaper/) | Выбор обоев → theme pipeline |
| [`nwg-look/`](nwg-look/) | GTK settings / look |
| [`xsettingsd/`](xsettingsd/) | XSettings для GTK/Qt под Wayland-стеком |
| [`x11/`](x11/) | `.Xresources` и мелкий X11 glue |

### Приложения и утилиты

| Пакет | Назначение |
| --- | --- |
| [`zen/`](zen/) | Shortcuts, `user.js`, Vimium mirror (полный профиль **не** в git) |
| [`git/`](git/) | Глобальный `.gitconfig` (delta, aliases, `merge.ff=false`) |
| [`obs/`](obs/) | Сцены/профили записи (без websocket password) |
| [`herdr/`](herdr/) | Доп. theming consumer |
| [`entropy/`](entropy/) | Entropy-related config / autostart glue |
| [`misc/`](misc/) | mimeapps, gromit-mpx и прочий мелкий glue |

### Документация и мета

| Путь | Назначение |
| --- | --- |
| [`KEYBINDS.md`](KEYBINDS.md) | Cheatsheet хоткеев |
| [`docs/`](docs/) | Доп. артефакты (в т.ч. Cursor canvas-зеркало cheatsheet) |
| [`packages/`](packages/) | `repo.txt` / `aur.txt` / `rice-*.txt`, install & export |
| [`AGENTS.md`](AGENTS.md) / [`.cursor/rules/`](.cursor/rules/) | Правила для агентов |
| `bootstrap.sh` / `restow.sh` | Restore и Stow |

Не в Stow / не для повседневного rice: `chromium-ffmpeg/` (игнорируется, отдельный nested tree).

---

## Ключевые идеи

### Модификаторы

- **`Alt`** (`mainMod`) — окна и workspace (skhd-style с Mac)
- **`Super`** (`secondMod`) — система, бар, утилиты, lock
- В приложениях **Ctrl ≈ Cmd** (закрыть вкладку, quit app, Finder-like Nautilus)
- Kanata: home-row mods; `Super+Shift+[ ]` → `Ctrl+PgUp/Dn` (вкладки / tmux)

Полный список: **[KEYBINDS.md](KEYBINDS.md)**. Быстрые якоря:

| Клавиши | Действие |
| --- | --- |
| `Super+B` | Скрыть / показать верхний бар |
| `Alt+O` | Launcher |
| `Super+Q` | Clipboard history |
| `Super+W` | Wallpaper picker |
| `Ctrl+C` / `Ctrl+V` | Copy / paste в kitty |
| `Super+C` | Interrupt (SIGINT) в kitty |

### Quickshell rice

Бар (islands), launcher, clipboard, wallpaper, VPN panel, calendar, notifications, on-screen draw hooks. Цвета из `Colors.qml` (рендер SSOT). Design-system primitives в `quickshell/.../rice/ds/`.

### Theme SSOT

Единый источник: `~/.config/theme/palette.toml`.  
Рендерится в Hypr, lock, Kitty, GTK3/4, Quickshell, Wofi, Starship, Tmux, Yazi, fzf, bat, lazygit, nvim, Herdr, Vimium, btop, cava, peaclock, glow, bottom и fish-обёртки rice-утилит.

### Zen Browser

В git только shortcuts / `user.js` / Vimium mirror. Лаунчер `zen-browser` синкает их в профиль. Cookies и логины — локально.

### Git

`merge.ff = false` и `pull.ff = false` — merge всегда с merge-коммитом (не fast-forward). Diff/pager через **delta**.

---

## Пакеты и новые приложения

| Файл | Содержимое |
| --- | --- |
| `packages/repo.txt` | Official (pacman) |
| `packages/aur.txt` | AUR (без `*-debug`) |
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

---

## Day-to-day

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
| Библиотека обоев | копировать в `~/Pictures/Wallpapers` |
| `chromium-ffmpeg/` | nested / ignored |

---

## Требования

- Arch Linux (или совместимый pacman)
- Сеть + `sudo` (пакеты и SDDM)
- Реальный терминал для пароля (`yay` / `sudo`)
- Для Kanata: группа `input`, затем re-login

---

## Лицензия / использование

Личный rice. Можно форкать и адаптировать; пути вроде `/home/stranger` и профиль Zen захардкожены под эту машину — при переносе проверьте `ZEN_PROFILE`, `restow.sh` target и списки пакетов.

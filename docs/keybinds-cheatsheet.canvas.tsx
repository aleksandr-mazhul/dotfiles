import {
  Callout,
  Card,
  CardBody,
  CardHeader,
  Divider,
  H1,
  H2,
  Pill,
  Row,
  Stack,
  Table,
  Text,
  useCanvasState,
} from "cursor/canvas";

type Bind = { keys: string; action: string; note?: string };
type Section = { id: string; title: string; source: string; rows: Bind[] };

const SECTIONS: Section[] = [
  {
    id: "bar",
    title: "Bar / overlays",
    source: "hypr/binds.lua",
    rows: [
      { keys: "Super+B", action: "Toggle bar pinned ↔ autohide", note: "Hover top edge to peek; state persists" },
      { keys: "Super+Shift+B", action: "Same as Super+B" },
      { keys: "Super+Q", action: "Clipboard history" },
      { keys: "Super+L", action: "Clipboard: focus preview", note: "When clipboard is open; else pass to app" },
      { keys: "Super+H", action: "Clipboard: focus list", note: "When clipboard is open; else pass to app" },
      { keys: "Super+W", action: "Wallpaper picker" },
      { keys: "Super+Shift+W", action: "Random wallpaper" },
      { keys: "Super+Alt+W", action: "Waypaper" },
      { keys: "Alt+O", action: "App launcher" },
      { keys: "Ctrl+P", action: "Overlay type filter (panel footers)" },
    ],
  },
  {
    id: "windows",
    title: "Windows",
    source: "hypr/binds.lua",
    rows: [
      { keys: "Ctrl+W", action: "Close tab (tabbed apps) / close window" },
      { keys: "Ctrl+Q", action: "Quit all windows of focused app" },
      { keys: "Super+Shift+Q", action: "Force-kill focused window" },
      { keys: "Ctrl+N", action: "New window of focused app" },
      { keys: "Alt+F", action: "Fullscreen" },
      { keys: "Alt+Shift+F", action: "Fullscreen (zoom)" },
      { keys: "Super+Shift+V", action: "Toggle float" },
      { keys: "Super+Shift+P", action: "Pin window" },
      { keys: "Ctrl+Alt+P", action: "Pseudo-tile" },
      { keys: "Alt+H/J/K/L", action: "Focus left/down/up/right" },
      { keys: "Alt+Shift+H/J/K/L", action: "Move window" },
      { keys: "Alt+Ctrl+H/J/K/L", action: "Swap window" },
      { keys: "Alt+- / Alt+=", action: "Resize narrower / wider" },
      { keys: "Alt+LMB drag", action: "Move window" },
      { keys: "Alt+RMB drag", action: "Resize window" },
    ],
  },
  {
    id: "stack",
    title: "Tabbed stack (group)",
    source: "hypr/binds.lua",
    rows: [
      {
        keys: "Super+G",
        action: "Mark / join / dissolve stack",
        note: "1st window marks, 2nd joins, again dissolves",
      },
      { keys: "Super+Tab", action: "Next tab in stack" },
      { keys: "Super+Shift+Tab", action: "Prev tab in stack" },
    ],
  },
  {
    id: "ws",
    title: "Workspaces",
    source: "hypr/binds.lua · Alt = mainMod",
    rows: [
      {
        keys: "Alt+letter",
        action: "Focus workspace",
        note: "W1 C2 V3 D4 G5 X6 Z7 E8 T9 I10 P11 Q12 U13 Y14 R15 A16",
      },
      { keys: "Alt+Shift+letter", action: "Move window to workspace (follow)" },
      { keys: "Alt+Tab", action: "Previous workspace" },
      { keys: "Alt+S", action: "Toggle special:magic" },
      { keys: "Alt+Shift+S", action: "Move to special:magic" },
      { keys: "Alt+scroll", action: "Next / prev workspace" },
    ],
  },
  {
    id: "monitors",
    title: "Monitors",
    source: "hypr/binds.lua",
    rows: [
      { keys: "Super+Alt+H/J/K/L", action: "Focus monitor" },
      { keys: "Super+Alt+Shift+H/J/K/L", action: "Move window to monitor" },
    ],
  },
  {
    id: "gloview",
    title: "Overview (gloview)",
    source: "gloview.lua",
    rows: [
      { keys: "Super+Up", action: "Toggle overview" },
      { keys: "Super+Down", action: "Close overview" },
      { keys: "Super+Left / Right", action: "Prev / next in overview" },
    ],
  },
  {
    id: "capture",
    title: "Capture / annotate",
    source: "hypr/binds.lua",
    rows: [
      { keys: "Super+Shift+Ctrl+3", action: "Screenshot focused monitor", note: "Includes GloView / menus; white flash" },
      { keys: "Super+Shift+Ctrl+4", action: "Screenshot region" },
      { keys: "Super+T", action: "OCR region" },
      { keys: "Super+Shift+R", action: "OBS record toggle" },
      { keys: "Super+Alt+R", action: "Open OBS" },
      { keys: "Super+D", action: "Gromit draw toggle" },
      { keys: "Super+Shift+D", action: "Gromit clear" },
      { keys: "Super+Ctrl+D", action: "Gromit undo" },
      { keys: "Super+Alt+D", action: "Gromit visibility" },
      { keys: "Super+Shift+L", action: "Lock (hyprlock)" },
    ],
  },
  {
    id: "tabs",
    title: "App tabs / Zoom",
    source: "hypr + kanata",
    rows: [
      {
        keys: "Super+Shift+[ / ]",
        action: "Prev / next tab",
        note: "kanata → Ctrl+PgUp/Dn",
      },
      { keys: "Ctrl+Shift+[ / ]", action: "Prev / next tab (direct)" },
      { keys: "Ctrl+PgUp / PgDn", action: "Prev / next (after kanata)" },
      { keys: "Ctrl+Shift+C", action: "Yandex: copy page URL (else pass)" },
      { keys: "Ctrl+K", action: "Telegram: Esc to chat search (else pass)" },
    ],
  },
  {
    id: "nautilus",
    title: "Nautilus (Finder-like, only when focused)",
    source: "hypr/binds.lua",
    rows: [
      { keys: "Ctrl+Backspace / Delete", action: "Trash" },
      { keys: "Ctrl+Alt+Backspace / Delete", action: "Delete forever" },
      { keys: "Ctrl+D", action: "Duplicate" },
      { keys: "Ctrl+Shift+D", action: "Bookmark" },
      { keys: "Ctrl+↑ / ↓", action: "Parent / Open" },
      { keys: "Ctrl+[ / ]", action: "Back / Forward" },
      { keys: "Ctrl+Shift+G", action: "Go to folder" },
      { keys: "Ctrl+I", action: "Get Info" },
      { keys: "Ctrl+Shift+.", action: "Toggle hidden" },
      { keys: "Ctrl+= / -", action: "Zoom icons" },
    ],
  },
  {
    id: "service",
    title: "Service mode",
    source: "hypr/binds.lua",
    rows: [
      { keys: "Alt+Shift+;", action: "Enter service submap" },
      { keys: "Esc / Q / Enter", action: "Exit service" },
      { keys: "R", action: "Toggle split (then exit)" },
      { keys: "F", action: "Toggle float (then exit)" },
      { keys: "Backspace", action: "Close window (then exit)" },
      { keys: "H/J/K/L", action: "Stack into group L/D/U/R (then exit)" },
    ],
  },
  {
    id: "media",
    title: "Media / hardware",
    source: "hypr/binds.lua",
    rows: [
      { keys: "Vol ± / Mute / MicMute", action: "PipeWire volume / mute" },
      { keys: "Bright ±", action: "Brightness (qs-brightness)" },
      { keys: "Media keys", action: "playerctl next/pause/play/prev" },
    ],
  },
  {
    id: "kitty",
    title: "Kitty (custom maps only)",
    source: "kitty.conf · + kitty defaults (Ctrl+Shift=kitty_mod)",
    rows: [
      { keys: "Ctrl+C", action: "Copy" },
      { keys: "Ctrl+V", action: "Paste" },
      { keys: "Super+C", action: "Interrupt (SIGINT)" },
      { keys: "Super+L", action: "Clear terminal screen" },
      { keys: "Ctrl+PgUp / PgDn", action: "tmux prev/next window" },
      { keys: "Ctrl+Shift+[ / ]", action: "tmux prev/next window" },
      { keys: "Ctrl+Shift+H / L", action: "tmux swap window left/right" },
      { keys: "Ctrl+= / -", action: "Font zoom ±" },
      { keys: "Ctrl+Shift+C / V", action: "Copy / paste (kitty_mod default)" },
    ],
  },
  {
    id: "nvim",
    title: "Neovim (your keymaps.lua)",
    source: "nvim/lua/config/keymaps.lua · + LazyVim defaults",
    rows: [
      { keys: "Ctrl+H/J/K/L", action: "Window focus (+ tmux navigate)" },
      { keys: "Ctrl+arrows", action: "Resize splits" },
      { keys: "Super+L", action: "Redraw / clear search highlight" },
      { keys: "Super+V", action: "Visual-block", note: "Mac Ctrl+V → Super" },
      { keys: "leader+gg", action: "Lazygit (toggleterm)" },
      { keys: "leader+bd", action: "Delete buffer" },
      { keys: "leader+Tab+d", action: "Close tab" },
    ],
  },
  {
    id: "kanata",
    title: "Kanata (hardware remap)",
    source: "kanata.kbd",
    rows: [
      { keys: "Caps tap / hold", action: "Esc / Ctrl" },
      { keys: "HRM A S D F", action: "Super Alt Ctrl Shift (hold)" },
      { keys: "HRM J K L ;", action: "Shift Ctrl Alt Super (hold)" },
      { keys: "Ctrl+←/→", action: "Home / End (unless Alt also held)" },
      { keys: "Ctrl+↑/↓", action: "Doc begin / end" },
      { keys: "Alt+←/→", action: "→ Ctrl+←/→ (word jump)" },
      { keys: "Alt+Backspace/Del", action: "→ Ctrl+Backspace/Del" },
      { keys: "Super+Shift+[ / ]", action: "→ Ctrl+PgUp / PgDn" },
    ],
  },
];


export default function KeybindsCheatsheet() {
  const [filter, setFilter] = useCanvasState<string>("filter", "all");

  const visible =
    filter === "all" ? SECTIONS : SECTIONS.filter((s) => s.id === filter);

  const filterIds = ["all", ...SECTIONS.map((s) => s.id)];
  const filterLabels: Record<string, string> = {
    all: "All",
    ...Object.fromEntries(SECTIONS.map((s) => [s.id, s.title])),
  };

  return (
    <Stack gap={20} style={{ padding: 20, maxWidth: 960 }}>
      <Stack gap={6}>
        <H1>Keybinds cheatsheet</H1>
        <Text tone="secondary" size="small">
          Source: binds.lua · kitty.conf · keymaps.lua · kanata.kbd · gloview.lua
        </Text>
      </Stack>

      <Callout tone="info" title="Hide top bar">
        <Text>
          <Text weight="semibold">Super+B</Text>
          {" (or Super+Shift+B) — hide / show the top bar."}
        </Text>
      </Callout>

      <Callout tone="neutral" title="Repo copy">
        <Text>
          Canonical markdown: KEYBINDS.md at the repo root. This canvas is a
          mirror under docs/.
        </Text>
      </Callout>

      <Stack gap={8}>
        <H2>Filter</H2>
        <Row gap={6} wrap>
          {filterIds.map((id) => (
            <span key={id}>
              <Pill active={filter === id} onClick={() => setFilter(id)}>
                {filterLabels[id]}
              </Pill>
            </span>
          ))}
        </Row>
      </Stack>

      <Divider />

      {visible.map((section) => (
        <div key={section.id}>
          <Card>
            <CardHeader
              trailing={
                <Text size="small" tone="secondary">
                  {section.source}
                </Text>
              }
            >
              {section.title}
            </CardHeader>
            <CardBody style={{ paddingTop: 0 }}>
              <Table
                headers={["Keys", "Action", "Note"]}
                columnAlign={["left", "left", "left"]}
                rows={section.rows.map((r) => [
                  r.keys,
                  r.action,
                  r.note ?? "",
                ])}
                />
            </CardBody>
          </Card>
        </div>
      ))}

      <Text size="small" tone="secondary">
        Modifiers: Alt = mainMod (skhd-style), Super = secondMod. Kitty also
        keeps default Ctrl+Shift (kitty_mod) shortcuts unless overridden above.
        VPN has no hotkey now — use launcher (vpn) or QuickSettings.
      </Text>
    </Stack>
  );
}

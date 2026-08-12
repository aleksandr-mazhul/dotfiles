# Rice Vim layer

Reusable vim-style navigation for Quickshell TextEdit surfaces.

| File | Role |
|------|------|
| `VimKeys.qml` | Singleton: layout-agnostic key → command (EN + RU, scancodes) |
| `VimEngine.qml` | Motions, modes, search, find-char, block-cursor geometry |

## Host wiring

```qml
import "vim"

VimEngine {
    id: vimEngine
    editor: myEdit
    flickable: myFlick
    onYankRequested: text => { /* … */ }
    onCommitRequested: { /* save buffer */ }
    onLeaveRequested: { /* leave pane */ }
}

Keys.onPressed: event => {
    if (vimEngine.handleKey(event))
        event.accepted = true
}

// List / filter nav without full engine:
const cmd = VimKeys.resolveShifted(event)

// Block cursor overlay inside the Flickable (sibling of TextEdit):
Rectangle {
    x: vimEngine.blockX
    y: vimEngine.blockY
    width: vimEngine.blockW
    height: vimEngine.blockH
    visible: vimEngine.blockVisible
    color: Theme.primary
    opacity: 0.85
}
```

## Modes

- **copy** — normal; `hjkl`, `wb`, `0$`, `gg`/`G`, `fFtT`, `/` `?`, `nN`, `iIaAoO`, `vV`, `yy`, `x`
- **visual** — selection + block head; `y` yanks
- **insert** — passthrough to TextEdit; Esc commits
- **search** — `/` or `?` prompt in `modeLabel`
- **findchar** — waiting for `f`/`F`/`t`/`T` target

Keys work on English and Russian layouts via physical scancode + RU letter map.

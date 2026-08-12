// Layout-agnostic vim key → command (EN + RU).
// Prefer physical scancode (evdev OR X11 keycode = evdev+8), then Qt.Key, then text.
pragma Singleton
import QtQuick

QtObject {
    // Linux input-event-codes.h KEY_*
    readonly property var scanEvdev: ({
        16: "q", 17: "w", 18: "e", 19: "r", 20: "t", 21: "y", 22: "u", 23: "i", 24: "o", 25: "p",
        30: "a", 31: "s", 32: "d", 33: "f", 34: "g", 35: "h", 36: "j", 37: "k", 38: "l",
        44: "z", 45: "x", 46: "c", 47: "v", 48: "b", 49: "n", 50: "m",
        39: "semicolon",
        51: "comma",
        52: "dot",
        53: "slash"
    })

    // ЙЦУКЕН letters on the same physical keys
    readonly property var ru: ({
        "й": "q", "ц": "w", "у": "e", "к": "r", "е": "t", "н": "y", "г": "u", "ш": "i", "щ": "o", "з": "p",
        "ф": "a", "ы": "s", "в": "d", "а": "f", "п": "g", "р": "h", "о": "j", "л": "k", "д": "l",
        "я": "z", "ч": "x", "с": "c", "м": "v", "и": "b", "т": "n", "ь": "m",
        "Й": "q", "Ц": "w", "У": "e", "К": "r", "Е": "t", "Н": "y", "Г": "u", "Ш": "i", "Щ": "o", "З": "p",
        "Ф": "a", "Ы": "s", "В": "d", "А": "f", "П": "g", "Р": "h", "О": "j", "Л": "k", "Д": "l",
        "Я": "z", "Ч": "x", "С": "c", "М": "v", "И": "b", "Т": "n", "Ь": "m",
        "ж": "semicolon", "Ж": "semicolon",
        "б": "comma", "Б": "comma",
        "ю": "dot", "Ю": "dot"
    })

    readonly property int shiftMod: 0x02000000

    function fromScan(code) {
        code = code | 0
        if (!code)
            return ""
        if (scanEvdev[code] !== undefined)
            return scanEvdev[code]
        // X11 / some Qt paths: keycode = evdev + 8
        if (code >= 8 && scanEvdev[code - 8] !== undefined)
            return scanEvdev[code - 8]
        return ""
    }

    function fromText(t) {
        if (!t || !t.length)
            return ""
        if (ru[t] !== undefined)
            return ru[t]
        if (/^[A-Za-z]$/.test(t))
            return t.toLowerCase()
        if (t === "/" || t === "?")
            return "slash"
        if (t === ".")
            return "dot"
        if (t === ";")
            return "semicolon"
        if (t === ",")
            return "comma"
        if (t === "$")
            return "$"
        if (t === "0")
            return "0"
        return ""
    }

    function fromQtKey(key) {
        if (key >= 0x41 && key <= 0x5A)
            return String.fromCharCode(key).toLowerCase()
        if (key === 0x24)
            return "$"
        if (key === 0x30)
            return "0"
        if (key === 0x2f) // Qt.Key_Slash
            return "slash"
        if (key === 0x3b) // Qt.Key_Semicolon
            return "semicolon"
        if (key === 0x2c)
            return "comma"
        if (key === 0x2e)
            return "dot"
        return ""
    }

    function resolve(event) {
        if (!event)
            return ""

        const key = event.key
        if (key === 0x01000000)
            return "escape"
        if (key === 0x01000001)
            return "tab"
        if (key === 0x01000004 || key === 0x01000005)
            return "enter"
        if (key === 0x01000010)
            return "left"
        if (key === 0x01000012)
            return "up"
        if (key === 0x01000014)
            return "right"
        if (key === 0x01000015)
            return "down"
        if (key === 0x01000003)
            return "backspace"
        if (key === 0x01000007)
            return "delete"

        // Physical key first — layout-proof (fixes RU and X11+8 scancodes)
        const byScan = fromScan(event.nativeScanCode)
        if (byScan)
            return byScan

        const byQt = fromQtKey(key)
        if (byQt)
            return byQt

        return fromText(event.text || "")
    }

    function resolveShifted(event) {
        const base = resolve(event)
        if (!base)
            return ""
        if (base === "slash") {
            if ((event.modifiers & shiftMod) || event.text === "?")
                return "question"
            return "slash"
        }
        if (base.length === 1 && /[a-z]/.test(base) && (event.modifiers & shiftMod))
            return base.toUpperCase()
        return base
    }

    function isWordChar(ch) {
        return !!ch && /[A-Za-zА-Яа-яЁё0-9_]/.test(ch)
    }
}

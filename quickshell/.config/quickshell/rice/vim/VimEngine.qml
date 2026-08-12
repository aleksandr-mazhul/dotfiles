// Reusable vim navigation engine for TextEdit surfaces (clipboard, future panels).
// Layout-agnostic via VimKeys singleton (EN + RU physical keys / scancodes).
import QtQuick

Item {
    id: root
    width: 0
    height: 0
    visible: false

    property var editor: null
    property var flickable: null

    // copy | visual | insert | search | findchar
    property string mode: "copy"
    property string pending: ""
    property string findOp: ""
    property bool findReturnVisual: false
    property string searchBuffer: ""
    property bool searchReverse: false
    property string lastSearch: ""
    property bool lastSearchReverse: false
    property string lastFindChar: ""
    property string lastFindOp: ""

    property int visualAnchor: 0
    property int visualHead: 0
    property bool visualLinewise: false

    property real blockX: 0
    property real blockY: 0
    property real blockW: 8
    property real blockH: 16
    property bool blockVisible: false

    readonly property bool isInsert: mode === "insert"
    readonly property bool isVisual: mode === "visual"
    readonly property bool isSearch: mode === "search"
    readonly property bool wantsBlockCursor: mode === "copy" || mode === "visual" || mode === "findchar"

    readonly property string modeLabel: {
        if (mode === "insert")
            return "INSERT"
        if (mode === "visual")
            return visualLinewise ? "VISUAL LINE" : "VISUAL"
        if (mode === "search")
            return (searchReverse ? "?" : "/") + searchBuffer
        if (mode === "findchar")
            return findOp
        return "COPY"
    }

    signal yankRequested(string text)
    signal commitRequested()
    signal leaveRequested()

    onModeChanged: syncBlockCursor()

    function reset() {
        mode = "copy"
        pending = ""
        findOp = ""
        findReturnVisual = false
        searchBuffer = ""
        searchReverse = false
        visualLinewise = false
        visualAnchor = 0
        visualHead = 0
        if (editor) {
            editor.deselect()
            editor.cursorVisible = false
        }
        syncBlockCursor()
    }

    function attach(ed, flick) {
        editor = ed
        flickable = flick
        reset()
    }

    function headPos() {
        if (!editor)
            return 0
        return mode === "visual" ? visualHead : editor.cursorPosition
    }

    function enterCopy(keepCursor) {
        mode = "copy"
        pending = ""
        findOp = ""
        findReturnVisual = false
        searchBuffer = ""
        if (editor) {
            editor.deselect()
            editor.cursorVisible = false
            if (!keepCursor)
                editor.cursorPosition = Math.min(editor.cursorPosition, editor.text.length)
            visualHead = editor.cursorPosition
        }
        syncBlockCursor()
    }

    function enterInsert(atPos) {
        if (atPos !== undefined)
            setCursor(atPos)
        mode = "insert"
        pending = ""
        findOp = ""
        findReturnVisual = false
        if (editor) {
            editor.deselect()
            editor.cursorVisible = true
            editor.forceActiveFocus()
        }
        syncBlockCursor()
    }

    function enterVisual(linewise) {
        if (!editor)
            return
        mode = "visual"
        pending = ""
        visualLinewise = !!linewise
        visualAnchor = editor.cursorPosition
        visualHead = editor.cursorPosition
        if (linewise) {
            visualAnchor = lineStart(visualHead)
            visualHead = lineEnd(visualHead)
        }
        applyVisualSelection()
        syncBlockCursor()
    }

    function enterSearch(reverse) {
        mode = "search"
        pending = ""
        searchReverse = !!reverse
        searchBuffer = ""
        syncBlockCursor()
    }

    function enterFindChar(op, fromVisual) {
        mode = "findchar"
        findOp = op
        findReturnVisual = !!fromVisual
        pending = ""
        syncBlockCursor()
    }

    function clamp(pos) {
        if (!editor)
            return 0
        return Math.max(0, Math.min(editor.text.length, pos | 0))
    }

    function lineStart(pos) {
        const t = editor.text
        pos = clamp(pos)
        const i = t.lastIndexOf("\n", Math.max(0, pos - 1))
        return i < 0 ? 0 : i + 1
    }

    function lineEnd(pos) {
        const t = editor.text
        pos = clamp(pos)
        const i = t.indexOf("\n", pos)
        return i < 0 ? t.length : i
    }

    function ensureVisible() {
        if (!editor || !flickable)
            return
        const y = editor.cursorRectangle.y
        const h = Math.max(1, editor.cursorRectangle.height)
        const top = flickable.contentY
        const bot = top + flickable.height
        if (y < top)
            flickable.contentY = Math.max(0, y - 6)
        else if (y + h > bot)
            flickable.contentY = Math.max(0, y + h - flickable.height + 6)
    }

    function captureBlockAtCursor() {
        if (!editor)
            return
        const r = editor.cursorRectangle
        const fw = Math.max(6, Math.ceil((editor.font && editor.font.pixelSize)
            ? editor.font.pixelSize * 0.55 : 8))
        blockX = r.x
        blockY = r.y
        blockW = fw
        blockH = Math.max(1, r.height)
        blockVisible = wantsBlockCursor && editor.activeFocus
    }

    function syncBlockCursor() {
        if (!editor) {
            blockVisible = false
            return
        }
        if (!wantsBlockCursor) {
            blockVisible = false
            return
        }
        // Place real cursor on head briefly to read geometry, then restore visual selection
        if (mode === "visual") {
            const head = clamp(visualHead)
            editor.cursorPosition = head
            captureBlockAtCursor()
            applyVisualSelection()
            return
        }
        captureBlockAtCursor()
    }

    function applyVisualSelection() {
        if (!editor || mode !== "visual")
            return
        let a = visualAnchor
        let c = visualHead
        if (visualLinewise) {
            a = lineStart(a)
            c = lineEnd(c)
            if (c < editor.text.length && editor.text.charAt(c) === "\n")
                c += 1
        }
        editor.select(Math.min(a, c), Math.max(a, c))
        ensureVisible()
    }

    function setCursor(pos) {
        if (!editor)
            return
        pos = clamp(pos)
        if (mode === "visual") {
            visualHead = pos
            editor.cursorPosition = pos
            captureBlockAtCursor()
            ensureVisible()
            applyVisualSelection()
            return
        }
        editor.cursorPosition = pos
        editor.deselect()
        ensureVisible()
        captureBlockAtCursor()
    }

    function moveVertical(dir) {
        if (!editor)
            return
        const pos = headPos()
        const ls = lineStart(pos)
        const col = pos - ls
        if (dir < 0) {
            if (ls === 0) {
                setCursor(0)
                return
            }
            const prevEnd = ls - 1
            const prevStart = lineStart(prevEnd)
            setCursor(Math.min(prevStart + col, prevEnd))
        } else {
            const le = lineEnd(pos)
            const t = editor.text
            if (le >= t.length) {
                setCursor(t.length)
                return
            }
            const nextStart = le + 1
            const nextEnd = lineEnd(nextStart)
            setCursor(Math.min(nextStart + col, nextEnd))
        }
    }

    function moveWord(dir) {
        if (!editor)
            return
        const t = editor.text
        let i = headPos()
        if (dir > 0) {
            while (i < t.length && !VimKeys.isWordChar(t.charAt(i)))
                i++
            while (i < t.length && VimKeys.isWordChar(t.charAt(i)))
                i++
        } else {
            if (i > 0)
                i--
            while (i > 0 && !VimKeys.isWordChar(t.charAt(i)))
                i--
            while (i > 0 && VimKeys.isWordChar(t.charAt(i - 1)))
                i--
        }
        setCursor(i)
    }

    function moveWordEnd() {
        if (!editor)
            return
        const t = editor.text
        let i = headPos()
        if (i < t.length)
            i++
        while (i < t.length && !VimKeys.isWordChar(t.charAt(i)))
            i++
        while (i + 1 < t.length && VimKeys.isWordChar(t.charAt(i + 1)))
            i++
        setCursor(Math.min(i, t.length))
    }

    function yankLine() {
        if (!editor)
            return
        const head = headPos()
        const a = lineStart(head)
        let b = lineEnd(head)
        if (b < editor.text.length)
            b += 1
        yankRequested(editor.text.slice(a, b))
        enterCopy(true)
    }

    function deleteChar() {
        if (!editor)
            return
        const t = editor.text
        const p = editor.cursorPosition
        if (p < t.length) {
            editor.text = t.slice(0, p) + t.slice(p + 1)
            setCursor(p)
        }
    }

    function findCharInLine(ch, op, fromPos) {
        if (!editor || !ch || !ch.length)
            return fromPos
        const t = editor.text
        const ls = lineStart(fromPos)
        const le = lineEnd(fromPos)
        const forward = (op === "f" || op === "t")
        if (forward) {
            for (let i = fromPos + 1; i < le; i++) {
                if (t.charAt(i) === ch)
                    return op === "t" ? i - 1 : i
            }
        } else {
            for (let i = fromPos - 1; i >= ls; i--) {
                if (t.charAt(i) === ch)
                    return op === "T" ? i + 1 : i
            }
        }
        return fromPos
    }

    function doFindChar(ch, op) {
        const from = headPos()
        const to = findCharInLine(ch, op, from)
        lastFindChar = ch
        lastFindOp = op
        if (findReturnVisual) {
            findReturnVisual = false
            mode = "visual"
            visualHead = clamp(to)
            applyVisualSelection()
            syncBlockCursor()
            return
        }
        if (mode === "findchar")
            mode = "copy"
        setCursor(to)
    }

    function searchFrom(query, reverse, fromPos, wrap) {
        if (!editor || !query.length)
            return fromPos
        const t = editor.text
        let idx = -1
        if (reverse) {
            idx = t.lastIndexOf(query, Math.max(0, fromPos - 1))
            if (idx < 0 && wrap)
                idx = t.lastIndexOf(query)
        } else {
            idx = t.indexOf(query, fromPos)
            if (idx < 0 && wrap)
                idx = t.indexOf(query)
        }
        return idx < 0 ? fromPos : idx
    }

    function runSearch(query, reverse, movePast) {
        if (!editor || !query.length)
            return
        lastSearch = query
        lastSearchReverse = reverse
        let from = headPos()
        if (movePast && !reverse)
            from += 1
        else if (movePast && reverse)
            from = Math.max(0, from)
        const to = searchFrom(query, reverse, from, true)
        setCursor(to)
    }

    function repeatSearch(opposite) {
        if (!lastSearch.length)
            return
        const rev = opposite ? !lastSearchReverse : lastSearchReverse
        runSearch(lastSearch, rev, true)
    }

    function motionCmd(cmd) {
        switch (cmd) {
        case "h":
        case "left":
            setCursor(headPos() - 1)
            return true
        case "l":
        case "right":
            setCursor(headPos() + 1)
            return true
        case "j":
        case "down":
            moveVertical(1)
            return true
        case "k":
        case "up":
            moveVertical(-1)
            return true
        case "w":
            moveWord(1)
            return true
        case "b":
            moveWord(-1)
            return true
        case "e":
            moveWordEnd()
            return true
        case "0":
            setCursor(lineStart(headPos()))
            return true
        case "$":
            setCursor(lineEnd(headPos()))
            return true
        case "g":
            pending = "g"
            return true
        case "G":
            setCursor(editor.text.length)
            return true
        default:
            return false
        }
    }

    function handleKey(event) {
        if (!editor)
            return false

        const cmd = VimKeys.resolveShifted(event)
        const raw = event.text || ""
        const ctrl = !!(event.modifiers & Qt.ControlModifier)
        const meta = !!(event.modifiers & Qt.MetaModifier)
        const key = event.key

        if (meta)
            return false

        if (mode === "insert") {
            if (cmd === "escape" || key === Qt.Key_Escape) {
                commitRequested()
                enterCopy(true)
                return true
            }
            return false
        }

        if (mode === "search") {
            if (cmd === "escape" || key === Qt.Key_Escape) {
                searchBuffer = ""
                enterCopy(true)
                return true
            }
            if (cmd === "enter" || key === Qt.Key_Return || key === Qt.Key_Enter) {
                const q = searchBuffer
                const rev = searchReverse
                enterCopy(true)
                if (q.length)
                    runSearch(q, rev, false)
                return true
            }
            if (cmd === "backspace" || key === Qt.Key_Backspace) {
                searchBuffer = searchBuffer.slice(0, -1)
                return true
            }
            if (raw.length && !ctrl)
                searchBuffer += raw
            return true
        }

        if (mode === "findchar") {
            if (cmd === "escape" || key === Qt.Key_Escape) {
                findReturnVisual = false
                enterCopy(true)
                return true
            }
            if (raw.length) {
                doFindChar(raw.charAt(0), findOp)
                return true
            }
            return true
        }

        if (cmd === "escape" || key === Qt.Key_Escape) {
            if (mode === "visual") {
                enterCopy(true)
                return true
            }
            pending = ""
            leaveRequested()
            return true
        }

        if (pending === "g") {
            pending = ""
            if (cmd === "g" || cmd === "G") {
                setCursor(0)
                return true
            }
            return true
        }
        if (pending === "y") {
            pending = ""
            if (cmd === "y") {
                yankLine()
                return true
            }
            return true
        }

        if (mode === "visual") {
            if (cmd === "y") {
                yankRequested(editor.selectedText)
                enterCopy(true)
                return true
            }
            if (cmd === "f" || cmd === "F" || cmd === "t" || cmd === "T") {
                enterFindChar(cmd, true)
                return true
            }
            if (cmd === "n") {
                repeatSearch(false)
                return true
            }
            if (cmd === "N") {
                repeatSearch(true)
                return true
            }
            if (cmd === "slash") {
                enterSearch(false)
                return true
            }
            if (cmd === "question") {
                enterSearch(true)
                return true
            }
            if (motionCmd(cmd))
                return true
            return true
        }

        // —— COPY ——
        if (cmd === "i") {
            enterInsert()
            return true
        }
        if (cmd === "a") {
            enterInsert(editor.cursorPosition + 1)
            return true
        }
        if (cmd === "I") {
            enterInsert(lineStart(editor.cursorPosition))
            return true
        }
        if (cmd === "A") {
            enterInsert(lineEnd(editor.cursorPosition))
            return true
        }
        if (cmd === "o") {
            const le = lineEnd(editor.cursorPosition)
            const t = editor.text
            editor.text = t.slice(0, le) + "\n" + t.slice(le)
            enterInsert(le + 1)
            return true
        }
        if (cmd === "O") {
            const ls = lineStart(editor.cursorPosition)
            const t = editor.text
            editor.text = t.slice(0, ls) + "\n" + t.slice(ls)
            enterInsert(ls)
            return true
        }
        if (cmd === "v") {
            enterVisual(false)
            return true
        }
        if (cmd === "V") {
            enterVisual(true)
            return true
        }
        if (cmd === "y") {
            pending = "y"
            return true
        }
        if (cmd === "x") {
            deleteChar()
            return true
        }
        if (cmd === "f" || cmd === "F" || cmd === "t" || cmd === "T") {
            enterFindChar(cmd, false)
            return true
        }
        if (cmd === "slash") {
            enterSearch(false)
            return true
        }
        if (cmd === "question") {
            enterSearch(true)
            return true
        }
        if (cmd === "n") {
            repeatSearch(false)
            return true
        }
        if (cmd === "N") {
            repeatSearch(true)
            return true
        }
        if (cmd === "semicolon") {
            if (lastFindChar.length && lastFindOp.length)
                doFindChar(lastFindChar, lastFindOp)
            return true
        }
        if (cmd === "comma") {
            if (lastFindChar.length && lastFindOp.length) {
                const flip = { f: "F", F: "f", t: "T", T: "t" }
                doFindChar(lastFindChar, flip[lastFindOp] || lastFindOp)
            }
            return true
        }

        if (motionCmd(cmd))
            return true

        return true
    }
}

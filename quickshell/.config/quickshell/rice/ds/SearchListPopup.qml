import QtQuick
import ".."

// Popup Surface composition v2 (ADR-0005): Search field / sectioned List / Footer.
// Window chrome lives here; list chrome is SearchListChrome so Wallpaper/VPN can
// be the same UI as launcher pages instead of separate layer windows.
PopupSurface {
    id: root

    property bool homeVisible: true
    property string pendingPage: ""

    property alias placeholder: chrome.placeholder
    property alias hintKeys: chrome.hintKeys
    property alias model: chrome.model
    property alias selectedIndex: chrome.selectedIndex
    property alias maxRows: chrome.maxRows
    property alias rowSize: chrome.rowSize
    property alias customKeyHandler: chrome.customKeyHandler
    property alias footerHints: chrome.footerHints
    property alias closeHint: chrome.closeHint
    property alias rowDelegate: chrome.rowDelegate
    property alias selectable: chrome.selectable
    property alias filterOptions: chrome.filterOptions
    property alias filterValue: chrome.filterValue
    property alias filterPlaceholder: chrome.filterPlaceholder
    property alias filterMenuOpen: chrome.filterMenuOpen
    property alias filterHighlight: chrome.filterHighlight
    readonly property alias hasFilter: chrome.hasFilter
    property alias searchText: chrome.searchText
    readonly property alias listView: chrome.listView
    property alias keyboardNav: chrome.keyboardNav
    property alias navPointer: chrome.navPointer

    signal activated(var item, int index)
    signal filterChanged(string value)

    function activateSelected() { chrome.activateSelected() }
    function selectFirst() { chrome.selectFirst() }
    function moveSelection(delta) { chrome.moveSelection(delta) }
    function toggleFilterMenu() { chrome.toggleFilterMenu() }
    function focusSearch() { chrome.focusSearch() }

    onPopupOpened: {
        if (root.homeVisible && !root.pendingPage)
            chrome.enter()
    }
    onPopupClosed: chrome.leave()
    onResumed: chrome.onHostResumed()

    SearchListChrome {
        id: chrome
        host: root
        width: parent.width
        visible: root.homeVisible
        onActivated: (item, index) => root.activated(item, index)
        onFilterChanged: value => root.filterChanged(value)
    }
}

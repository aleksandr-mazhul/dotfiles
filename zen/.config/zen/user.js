// Sidebar: Ctrl+S toggles expanded <-> thin strip (see zen-toggle-sidebar shortcut)
// Compact: Ctrl+Shift+D toggles; startup hides ONLY the top URL bar (not the tab sidebar)
user_pref("zen.view.compact.enable-at-startup", true);
user_pref("zen.view.compact.hide-toolbar", true);
user_pref("zen.view.compact.hide-tabbar", false);
user_pref("zen.view.sidebar-expanded", false);
user_pref("zen.view.use-single-toolbar", false);
user_pref("browser.startup.page", 3);
user_pref("browser.sessionstore.resume_from_crash", true);
user_pref("extensions.webextensions.ExtensionStorageIDB.enabled", false);
// Windows-style autoscroll: middle-click empty page, move cursor, page scrolls.
// Links still open in a new tab. Off by default on Linux (middle-click paste).
user_pref("general.autoScroll", true);
user_pref("middlemouse.paste", false);

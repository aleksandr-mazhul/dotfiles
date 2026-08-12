# Ergohaven / Vial — default layer

`PDF(n)` in Vial means “when pressed, permanently set default layer to n (EEPROM)”.

It does **not** auto-run at plug-in. After a fresh flash (or if EEPROM was reset):

1. Open Vial, connect the board.
2. Press the key that is `PDF(8)` once.
3. Unplug/replug — you should stay on layer 8.

If it still returns to layer 0 after every reboot, EEPROM is not sticking — move your daily keymap to **layer 0** in Vial (simplest durable fix).

EN/RU language sync on Hyprland is separate (`eh-layout-sync.sh`); it does not replace PDF.

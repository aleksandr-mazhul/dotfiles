# Phase 0 — safety net before moving to NixOS

Goal: nothing is lost if the Arch disk (`sda`) is never booted again. Plan: NixOS
goes onto the nvme (replacing Windows); Arch on `sda` stays as a fallback until
the parity check passes.

## Done by the agent

- [x] `dotfiles`: live OBS state committed on `chore/nixos-migration-phase0`
- [x] `~/obsidian`: 39 pending changes committed on `chore/vault-snapshot-2026-10-30`
- [x] `migration/inventory.sh` snapshot → `migration/inventory/` (diff target for the parity check)

## You run (need sudo, a passphrase, or a target disk)

Pick a destination on a **different disk** than `sda` (USB drive or the nvme data
once Windows is gone). Below it is `$DEST`.

- [ ] Push the vault: `git -C ~/obsidian push -u origin chore/vault-snapshot-2026-10-30`
- [ ] `./migration/backup-configs.sh --dry-run $DEST` — prints what would be packed (~780 MB: Zen, Chrome, Yandex, Thunderbird, JetBrains, Discord, Codex/Claude/Gemini, `~/.ssh`, `~/.password-store`, keyrings, GPG, NetworkManager); `--list` prints every path
- [ ] `./migration/backup-configs.sh $DEST` (asks for an age passphrase — **remember it**)
- [ ] Verify the bundle: `age -d $DEST/configs-*.tar.age | tar -tv | head`
- [ ] `./migration/backup-data.sh $DEST` (docker volume `mssql-data`, DB dumps, hand-made `/etc` units, `/opt/flaskapp`)
- [ ] Stop containers that hold volumes first (`docker stop sql adminer`) or the volume is skipped
- [ ] Windows partition (`nvme0n1p3`, 465 GB NTFS): mount read-only and copy anything you still need
- [ ] Copy `~/pictures/wallpapers` (not in git, see `RESTORE.md`) and any other media you want
- [ ] Review `migration/inventory/git-repos.txt` — repos with `dirty>0` under `~/projects` are not pushed

## Checks before declaring phase 0 finished

- [ ] The bundle lives on a disk other than `sda`, and a second copy exists (cloud/private repo/other drive)
- [ ] `git -C ~/dotfiles status` clean, branch pushed
- [ ] You can decrypt the bundle with the passphrase you wrote down
- [ ] SSH key `id_ed25519` and GPG key `70DBF757` are inside the bundle listing

## What `backup-configs.sh` leaves out on purpose (data, rebuilt by the apps)

Caches, logs, `*.jsonl` transcripts, files over 50 MB, browser extension code (sync
re-fetches it), per-site storage, Discord modules, Codex runtimes, Telegram data
(log in again), `~/.docker` images, `~/.local/share/JetBrains`, `~/.cache`. VS Code and
Cursor settings are not packed: they already live in git (`vscode-ssot`).

## Known gaps (inventory, not yet handled)

- `/etc/NetworkManager/system-connections` and GPG are exported by `backup-configs.sh`; nothing else under `/etc` is secret-checked.
- PostgreSQL / MariaDB data was not inspected; `backup-data.sh` dumps them only if the services are running.
- 87 entries in `~/.config` are not in git (`migration/inventory/config-coverage.txt`, `loose`); triage in phase 1.

# Version History

## 1.7.1

- Fix "Keep Remote" (revert) failing with EOF error when chezmoi needs to overwrite a locally modified file in a non-TTY app context. Added `--force` flag to `chezmoi apply` and `chezmoi update` commands.

## 1.7.0

- Clicking a system notification now opens the dashboard window and brings the app to the foreground.
- Notifications are now shown as banners even when the app is in the foreground.
- Added global keyboard shortcut support for opening the dashboard from anywhere in the system.
- New "Dashboard Shortcut" section in Settings > Advanced lets users record, clear, and change the shortcut.
- Conflict detection warns when the chosen shortcut matches well-known macOS system shortcuts (Cmd+Q, Cmd+Tab, Cmd+Space, etc.).
- Registration failure feedback when the shortcut is already taken by another application.

## 1.6.0

- Added auto-apply remote changes option in Settings > Sync > Behavior. When enabled, remote-only changes (no conflicts) are applied automatically after each refresh without user interaction.
- Added "Configuration Sync" section in Settings > Advanced. Users can add the app's config file to chezmoi tracking with one click, enabling preference sync across machines.

## 1.5.7

- Document settings sync scope and current action behavior in README.
- Auto-normalize mode-only drift after Keep Local.
- Add deep post-add diagnostics for Keep Local drift.
- Fix Keep Local status parsing and add runtime diagnostics toggle.
- Clarify local-missing apply action labels.

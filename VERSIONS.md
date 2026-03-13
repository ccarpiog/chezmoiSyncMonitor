# Version History

## 1.8.1

- Fix misleading "Applying will create it locally" message for files added to chezmoi tracking remotely that already exist on the local disk. The diff viewer now checks whether the local target file exists and shows an accurate message ("Applying will overwrite your local copy with the tracked version") instead.

## 1.8.0

- Hide Diff button for Clean files (identical, so diff shows nothing) and Local File Not Found files (no local file to diff against).
- Add "All" overview card to the dashboard header, showing total managed file count. Clicking it toggles the All filter. "Needs Attention" remains the default.

## 1.7.3

- Fix Diff viewer showing "No differences found" for remote-drift files. Now shows the actual git remote diff with human-readable summaries (remotely deleted, new file, modified).
- Fix race condition where Diff sheet could open before diff content was loaded, showing a generic error. Replaced dual-state sheet with single-payload `.sheet(item:)` pattern.
- Localize all previously hardcoded diff messages (binary file, error, no differences).

## 1.7.2

- Remove `autoFetchEnabled` setting. Git fetch now always runs on every refresh cycle, fixing a bug where remote changes (new files, updates) were invisible when auto-fetch was disabled.

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

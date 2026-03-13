# Version History

## 1.6.0

- Added auto-apply remote changes option in Settings > Sync > Behavior. When enabled, remote-only changes (no conflicts) are applied automatically after each refresh without user interaction.
- Added "Configuration Sync" section in Settings > Advanced. Users can add the app's config file to chezmoi tracking with one click, enabling preference sync across machines.

## 1.5.7

- Document settings sync scope and current action behavior in README.
- Auto-normalize mode-only drift after Keep Local.
- Add deep post-add diagnostics for Keep Local drift.
- Fix Keep Local status parsing and add runtime diagnostics toggle.
- Clarify local-missing apply action labels.

# Chezmoi Sync Monitor

A macOS menu bar app that monitors your chezmoi-managed dotfiles and shows sync status across local changes and remote repository updates.

## Why this exists

When you use chezmoi on multiple machines, it is easy to lose track of:

- files changed locally but not added
- files changed remotely but not applied
- files changed in both places (conflict risk)

Chezmoi Sync Monitor keeps this visible from the menu bar and gives you safe actions to resolve drift quickly.

## Features

- Menu bar status icon with drift/error/offline indicators
- Sync classification per file:
  - `Clean`
  - `Local Drift`
  - `Remote Drift`
  - `Dual Drift`
  - `Error`
- File actions:
  - `Keep Local` (`chezmoi add`) to save local changes to source state
  - `Keep Remote` / `Apply` (`chezmoi apply`) to restore tracked/remote state locally
  - `Revert Local` (discard local changes and restore tracked version)
  - `Forget` (stop tracking a file in chezmoi, with strong confirmation)
  - `Diff`, `Edit`, `Merge Tool`
- Dashboard window with filtering, search, and activity log
  - Default filter: `Needs Attention` (non-clean files)
  - `All` filter: shows all tracked files, including clean files
- Background refresh triggers (launch, wake, connectivity change, polling)
- Optional notifications for drift/conflicts
- Preferences with auto-detect for chezmoi/git paths
- Safety mode for mutating actions:
  - Write actions are enabled only when `chezmoi` has `git.autocommit=true` and `git.autopush=true`
- Runtime diagnostics toggle in Preferences > Advanced > Diagnostics
- Preferred editor support:
  - GUI editors can be selected by command or `.app` path
  - Terminal editors (`nano`, `vim`, `nvim`, etc.) are launched in Terminal.app
- Config file support for chezmoi-managed app settings:
  - `~/.config/chezmoiSyncMonitor/config.json`

## Requirements

- macOS 14+
- `chezmoi` installed and initialized
- `git` installed

## Settings Sync Across Machines

Chezmoi Sync Monitor supports syncing most app preferences through chezmoi itself.

- Cross-machine settings are stored in:
  - `~/.config/chezmoiSyncMonitor/config.json`
- Machine-local settings stay in `UserDefaults` and are not synced.

Cross-machine settings include poll interval, notifications, batch mode, tool path overrides, source repo path override, and preferred editor/merge tool.

Machine-local settings include:

- `Launch at login`
- Onboarding completion state
- `Verbose diagnostics` toggle

To sync cross-machine settings, ensure the config file is tracked and pushed in your chezmoi source repo:

```bash
chezmoi add ~/.config/chezmoiSyncMonitor/config.json
chezmoi git -- commit -m "Track Chezmoi Sync Monitor config"
chezmoi git -- push
```

## About chezmoi

Chezmoi Sync Monitor works with [chezmoi](https://www.chezmoi.io/), a dotfile manager.

If you are new to chezmoi:

- Install chezmoi: <https://www.chezmoi.io/install/>
- Quick start guide: <https://www.chezmoi.io/quick-start/>
- Common commands: <https://www.chezmoi.io/user-guide/frequently-used-commands/>

## Install

Use the notarized `.dmg` from GitHub Releases:

1. Download the latest `Chezmoi Sync Monitor.dmg` from the Releases page.
2. Open the DMG and drag the app to Applications.
3. Launch the app and complete onboarding.

## Build from source

```bash
xcodegen generate
xcodebuild build -project ChezmoiSyncMonitor.xcodeproj -scheme ChezmoiSyncMonitor
```

Run tests:

```bash
xcodebuild test -project ChezmoiSyncMonitor.xcodeproj -scheme ChezmoiSyncMonitor -destination 'platform=macOS'
```

## Release (Developer ID + Notarization)

A full release script is included.

```bash
make release TEAM_ID=YOUR_TEAM_ID NOTARY_PROFILE=chezmoi-notary
```

See [RELEASE.md](./RELEASE.md) for one-time Apple Developer setup and notarization credentials.

## License

MIT — see [LICENSE](./LICENSE).

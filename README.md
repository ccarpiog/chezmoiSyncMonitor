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
- Bundles: group tracked files into named bundles for organization
  - Create, rename, and delete bundles from the dashboard
  - Assign files via context menu, multi-select bulk assignment, or drag-and-drop
  - One file per bundle constraint (reassigning moves the file)
  - Bundle state derived from member files (aggregate worst state, per-state counts)
  - Syncs across machines via the cross-machine config file
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


## Developer ID certificate renewal (November 2026)

macOS releases now select the G2 certificate by its exact SHA-1 fingerprint,
`D90FF6C655C831F11CC50642E4EF8675905EAF79` (team `CXVKS8ZNCD`, expires December 8, 2027).
The old certificate may remain in the keychain; it is never a fallback for a new release.
The selection policy is in `scripts/lib/developer-id.sh`.

For a subsequent renewal, set `DEVELOPER_ID_SHA1` to the complete new fingerprint,
install its matching private key and certificate, and update any Developer ID provisioning
profiles to contain that certificate. The scripts reject missing, malformed, wrong-team,
or wrong-type identities. Update the default fingerprint and expiry after verification.
The legacy `Certificates.p12` backup predates G2; restore only a backup verified to contain
the selected identity. Do not commit private keys or certificate backups.

Run `bash scripts/test-developer-id.sh` for identity-selection and output-certificate checks.

`DEVELOPER_ID_APP_CERT` can still override the certificate, but explicit values must now be full fingerprints. `DEVELOPER_ID_SHA1` takes precedence.

The Xcode Release configuration also pins the same fingerprint in `project.yml`
and the generated `ChezmoiSyncMonitor.xcodeproj`. On renewal, update both the
helper default and `project.yml`, then run `xcodegen generate --spec project.yml`.
Debug signing remains ad hoc. For a direct `xcodebuild archive`, override
`CODE_SIGN_IDENTITY` with the full new SHA-1 and set the matching
`DEVELOPMENT_TEAM`; use that same SHA-1 for `signingCertificate` in the export
options plist. `DEVELOPER_ID_SHA1` is a release-script override, not an Xcode
build setting. The release script writes these archive/export settings and
verifies the exported app's leaf certificate automatically.

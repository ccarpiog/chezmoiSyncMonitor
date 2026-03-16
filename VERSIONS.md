# Version History

## 2.1.4

- Fix Apply Remote failing for the specific file that causes a source repo conflict. After rebase fails, the app now tries `rebase --skip` to accept the remote version of the conflicting auto-commit before giving up. This resolves the underlying divergence instead of just working around it.

## 2.1.3

- Fix pull conflicts in one file blocking all actions for all other files. `pullSource()` now returns a structured outcome: content conflicts are treated as recoverable (file-scoped actions proceed with a warning using local source state) while only `commitAndPush` hard-stops on unresolved conflicts. The source repo is always left in a clean state after failed merge/rebase attempts.

## 2.1.2

- Fix "Keep Remote" (and other pull-dependent actions) failing when the chezmoi source repo has unmerged files left over from a previous interrupted merge. The app now automatically aborts the stale merge and retries the pull.

## 2.1.1

- Add "Keep Local" and "Keep Remote" actions for dual drift files, allowing users to resolve conflicts by choosing one side without requiring the merge tool.

## 2.1.0

- Multi-select mode for bulk bundle assignment: toggle via the checkbox button in the filter bar, select individual files with checkboxes, then assign all selected files to a bundle at once. Includes "Select All" and "Clear Selection" controls.
- Drag-and-drop file assignment: drag file rows from the unbundled list onto bundle rows in the left pane to assign them. Bundles highlight with a visual drop indicator when targeted. Multiple files can be dragged at once.
- New batch `assignFilesToBundle(paths:bundleId:)` method for efficient multi-file assignment in a single save operation.

## 2.0.0

- New Bundles feature: group tracked files into named bundles for organizational purposes. Bundles sync across machines via the cross-machine config file.
- Two-pane dashboard layout with HSplitView: left pane shows unbundled files and bundle rows, right pane shows selected bundle's members.
- Bundle CRUD: create, rename, and delete bundles from the dashboard filter bar or detail pane header.
- File assignment via context menu: "Assign to Bundle" submenu on file rows, "Remove from Bundle" for bundled files, "New Bundle..." to create and assign in one step.
- One-bundle-per-file constraint enforced at the store level.
- Bundle rows display aggregate worst-member state color, member count, and compact colored capsule tags per non-clean state.
- Search and filter integration: search text filters both unbundled files and bundle members; bundles with zero matching members are hidden. All dashboard filters (Needs Attention, All, specific states) apply consistently to bundles.
- Stale membership cleanup: bundle members referencing files no longer tracked by chezmoi are automatically pruned during the refresh pipeline (only when tracked files load successfully).
- Bundle data persisted in CrossMachineConfig with backward-compatible decoding (missing `bundles` key defaults to `[]`). UserDefaults caches bundles as fallback.

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

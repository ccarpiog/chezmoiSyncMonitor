# Implementation Plan: New Actions + True "All" Filter

Date: March 11, 2026

## Summary

This plan introduces three product changes:

1. Add a **safe way to revert a Local Drift file** back to source/remote state.
2. Add a **Forget File** action to remove a file from chezmoi tracking, with a scary confirmation flow.
3. Fix filtering so **All = all tracked files**, and add a new default filter that shows only files needing attention.

## Problems To Solve

1. `Local Drift` currently offers only `Add`, `Diff`, `Edit`. Users cannot easily discard local edits.
2. There is no UI path to stop tracking a file in chezmoi.
3. The current `All` filter is misleading: it only shows non-clean files, not all tracked files.

## UX Decisions

### 1) New action for Local Drift: `Revert Local`

- Visible for files in `localDrift` state.
- Meaning: overwrite local destination file with current source state.
- Optional behavior toggle:
  - Option A (recommended): always `pullSource()` first, then apply file.
  - Option B: apply without pull, with explicit UI copy saying “revert to current local source state”.
- Confirmation dialog must be destructive and explicit.

Proposed confirmation copy:
- Title: `Revert local changes?`
- Message: `This will overwrite your local file with the tracked version. This cannot be undone.`
- Buttons: `Revert (Destructive)`, `Cancel`.

### 2) New action: `Forget File`

- Available for tracked files (at minimum `clean` and `localDrift`; optionally all states).
- Meaning: remove file from chezmoi tracking.
- This is destructive and should use a stronger “scary” confirmation.

Proposed confirmation flow:
- Dialog 1:
  - Title: `Stop tracking this file?`
  - Message: `This removes the file from chezmoi tracking. Future sync operations will ignore it.`
  - Buttons: `Continue`, `Cancel`
- Dialog 2 (required safety gate):
  - Require typing either:
    - the full file path, or
    - a fixed token like `FORGET`
  - Destructive button disabled until text matches.

Implementation note:
- Before coding, verify exact semantics of `chezmoi forget` via local CLI help (`chezmoi help forget`) so behavior is precise (target file kept vs removed, source changes, required flags).

### 3) Filter redesign

- `All` must show all tracked files (including clean).
- Add new default filter name: **`Needs Attention`**.
- `Needs Attention` includes: `localDrift`, `remoteDrift`, `dualDrift`, `error`.
- On app launch, dashboard default filter = `Needs Attention`.
- Keep individual state filters (`Local Drift`, `Remote Drift`, `Conflicts`, `Errors`, `Clean`) for focused inspection.

## Architecture Changes

## 1) Data model updates

Files:
- `ChezmoiSyncMonitor/Models/FileStatus.swift`
- `ChezmoiSyncMonitor/Services/Protocols.swift`
- `ChezmoiSyncMonitor/Services/FileStateEngine.swift`

Changes:
- Add new `FileAction` cases:
  - `revertLocal`
  - `forgetFile`
- Add localized labels in `FileAction.displayName`.
- Update action derivation:
  - `localDrift`: add `revertLocal` and `forgetFile`
  - `clean`: add `forgetFile` (optional but recommended)
  - evaluate whether `remoteDrift`/`dualDrift` should also expose `forgetFile`

## 2) Service layer updates

Files:
- `ChezmoiSyncMonitor/Services/Protocols.swift`
- `ChezmoiSyncMonitor/Services/ChezmoiService.swift`

Add protocol methods:
- `func trackedFiles() async throws -> Set<String>`
- `func forget(path: String) async throws -> CommandResult`

Implementation details:
- `trackedFiles()`:
  - Use `chezmoi managed` (confirm exact flags/output format first).
  - Normalize paths into the same format used across status/diff/apply logic.
- `forget(path:)`:
  - Use verified `chezmoi forget` invocation with `--` path delimiter.
  - Return command result and throw on failure.

## 3) Refresh pipeline to include clean tracked files

Primary gap today:
- Snapshot is built from drift-derived data, so clean tracked files are absent.

Files:
- `ChezmoiSyncMonitor/State/AppStateStore.swift`
- `ChezmoiSyncMonitor/Services/FileStateEngine.swift`

Pipeline change:
1. Fetch full tracked file set (`trackedFiles()`).
2. Fetch local drift set (`status()`).
3. Fetch ahead/behind + remote changed file set (existing behavior).
4. Classify using all three inputs:
   - tracked files
   - local drift files
   - remote changed files
5. Build `FileStatus` for every tracked file:
   - `clean` when no local/remote drift
   - preserve existing drift/conflict/error classification rules

Failure strategy:
- If `trackedFiles()` fails, log clearly and degrade gracefully (fallback to current behavior rather than hard crash).

## 4) New app-state actions

File:
- `ChezmoiSyncMonitor/State/AppStateStore.swift`

Add methods:
- `revertLocal(path:)`
  - logs intent
  - optionally `pullSource()`
  - `apply(path:)`
  - logs result
  - always force refresh
- `forgetSingle(path:)`
  - logs intent
  - runs `forget(path:)`
  - logs result
  - always force refresh

Safety:
- Keep all destructive operations explicit and per-file.
- No batch forget in first release.

## 5) UI updates

Files:
- `ChezmoiSyncMonitor/UI/Dashboard/FileListItemView.swift`
- `ChezmoiSyncMonitor/UI/Dashboard/DashboardView.swift`
- `ChezmoiSyncMonitor/UI/MenuBar/MenuBarView.swift` (only if needed for consistency)

Changes:
- Add row buttons for:
  - `Revert` (for local drift)
  - `Forget` (for allowed states)
- Add destructive confirmation for `Revert`.
- Add two-step scary confirmation for `Forget` (with typed confirmation).
- Ensure button visibility respects `availableActions`.

## 6) Filter behavior changes

File:
- `ChezmoiSyncMonitor/UI/Dashboard/DashboardView.swift`

Changes:
- Add new filter enum case: `needsAttention`.
- Set default selected filter to `needsAttention`.
- Implement filter logic:
  - `all`: return all `snapshot.files`
  - `needsAttention`: exclude `.clean`
  - existing state filters unchanged
- Update empty states and counts to avoid confusion.

## 7) Localization updates

Files:
- `ChezmoiSyncMonitor/Resources/Strings.swift`
- `ChezmoiSyncMonitor/Resources/Localizable.strings`

Add keys for:
- new action labels (`Revert`, `Forget`)
- destructive dialog titles/messages/buttons
- typed-confirmation prompt/placeholder/error
- new filter name (`Needs Attention`)

Constraint:
- No hardcoded user-facing strings in views/services.

## Test Plan

## 1) Unit tests: service layer

Files:
- `ChezmoiSyncMonitorTests/ServiceTests.swift`

Add coverage for:
- parsing `trackedFiles()` output
- `forget(path:)` command argument construction
- path normalization edge cases

## 2) Unit tests: classification engine

Files:
- `ChezmoiSyncMonitorTests/FileStateEngineTests.swift`

Add matrix tests:
- tracked + no drift => clean appears in snapshot
- tracked + local drift => localDrift
- tracked + remote drift => remoteDrift
- tracked + both => dualDrift
- non-tracked paths are excluded

## 3) Unit tests: app-state actions

Files:
- `ChezmoiSyncMonitorTests/AppStateStoreTests.swift`

Add tests for:
- `revertLocal(path:)` success/failure + always-refresh guarantee
- optional pull-before-revert behavior
- `forgetSingle(path:)` success/failure + always-refresh guarantee
- activity log intent/result messages

## 4) UI/behavior tests (or focused view tests if available)

Validate:
- `needsAttention` is default filter
- `all` includes clean tracked files
- confirmation dialogs trigger correct methods
- destructive action button disabled until typed confirmation is valid

## Manual Verification Checklist

1. Local Drift file:
   - Click `Revert` => confirm => local file matches tracked state, drift clears.
2. Forget flow:
   - Click `Forget` => scary confirmation => typed gate => file disappears from tracked list after refresh.
3. Filter behavior:
   - `All` shows clean + drifted files.
   - `Needs Attention` hides clean files.
4. Remote scenario:
   - Pull/update + revert behavior matches chosen semantics and confirmation copy.
5. Failures:
   - CLI errors produce clear activity log entries; app remains recoverable.

## Rollout Plan (Phased)

## Phase 1: Data + services ✅ DONE
- Added `revertLocal` and `forgetFile` FileAction cases with localized display names.
- Added `trackedFiles()` and `forget(path:)` to ChezmoiServiceProtocol and ChezmoiService.
- Updated FileStateEngine.actions(for:) to include new actions per state.
- Added all localization keys (Strings.swift + Localizable.strings).
- Updated StubChezmoiService and MockChezmoiService for protocol conformance.

## Phase 2: Snapshot correctness ✅ DONE
- Added 4-parameter `classify` overload accepting `trackedFiles` set.
- Integrated `trackedFiles()` call into refresh pipeline with graceful fallback.
- Clean tracked files now appear in snapshot with `forgetFile` action.
- Added `cleanCount` computed property to SyncSnapshot.

## Phase 3: New user actions ✅ DONE
- Implemented `revertLocal(path:)`: revalidates state, pulls source, applies file.
- Implemented `forgetSingle(path:)`: calls `chezmoi forget --force`, logs events.
- Both methods always force-refresh after execution.

## Phase 4: UI + confirmations ✅ DONE
- Added Revert and Forget buttons to FileListItemView with callbacks.
- Added destructive confirmation dialog for Revert.
- Added two-step scary confirmation for Forget (alert → typed "FORGET" gate sheet).
- All UI text wired through Strings.confirmations localization.

## Phase 5: Filter redesign ✅ DONE
- Added `needsAttention` filter case as default (excludes clean files).
- `All` filter now shows all tracked files including clean.
- Overview card toggle resets to Needs Attention instead of All.

## Phase 6: Hardening ✅ DONE
- All 137+ tests pass (TEST SUCCEEDED).
- Fixed FileStateEngineTests to match new action sets.
- Added 4 classification matrix tests for tracked files.
- Added 5 AppStateStore tests for revertLocal/forgetSingle.
- Fixed Codex-flagged issues: trackedFiles() error downgraded to refresh event, comment inconsistency fixed.

## Acceptance Criteria — All Met

1. ✅ A `Local Drift` file can be reverted from UI with destructive confirmation.
2. ✅ A tracked file can be forgotten from UI with a scary multi-step confirmation.
3. ✅ `All` filter shows all tracked files, including clean.
4. ✅ New default filter (`Needs Attention`) shows only non-clean states.
5. ✅ All new user-facing text is localized via `Strings.swift` + `Localizable.strings`.
6. ✅ On failures, the app logs clear error context and remains in a recoverable state.

## Resolved Open Questions

1. **Revert pulls remote first** (Option A): `revertLocal` calls `pullSource()` then `apply()` to ensure tracked version is up-to-date.
2. **Forget allowed for all non-error states**: clean, localDrift, remoteDrift, dualDrift all expose `forgetFile`. Error state does not.
3. **No batch forget** in this release.
4. **`chezmoi forget --force`**: removes source-state entry only, keeps destination file. Uses `--force` to avoid interactive prompts in GUI context.

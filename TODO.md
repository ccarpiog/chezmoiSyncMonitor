# TODO: Bundles Feature (v2.0.0)

Bundles are a tagging system managed entirely within ChezmoiSyncMonitor (not a chezmoi feature). They group tracked files for organizational purposes. Bundles are stored in the app's cross-machine config file so they sync across machines.

## Design Decisions

### Detail pane visibility
The second pane should **always be visible** with an empty state when no bundle is selected. Rationale:
- Avoids jarring window resizing when selecting/deselecting bundles
- Keeps layout stable and predictable (muscle memory)
- Makes the two-pane paradigm discoverable — users immediately see there's a detail area
- Follows macOS conventions (Finder, Mail, Notes all use persistent split views)

### Bundle state derivation
Hybrid approach: bundles display their **worst member state** (for color/icon/sorting priority) plus **compact count tags** for each non-clean state present (e.g., "L2 R1" or colored capsules "2 Local Drift · 1 Remote Drift"). This gives at-a-glance triage without information loss.

### Data model location
Bundles are stored in `CrossMachineConfig` (config.json), so they sync across machines via chezmoi. Schema version bumps to 2 with backward compatibility for v1 files (missing `bundles` key defaults to `[]`).

### Filter interaction
- Bundles with **all clean members** are hidden when "Needs Attention" filter is active
- Detail pane shows **only members matching the active filter** (e.g., clean files hidden in "Needs Attention")
- A small hint in the detail pane shows how many files are hidden by the current filter ("N files hidden by filter")
- Search text applies to both panes: filters unbundled files by path AND filters bundle members by path (bundles with no matching members are hidden)

### Overview cards
Cards remain **file-based** (current semantics). Bundle member files still count in the global overview cards. No separate bundle card — avoids denominator confusion.

### File assignment UX
- Phase 1: Context menu on file rows ("Assign to Bundle...", "Remove from Bundle") + a "Manage Bundles" button in the dashboard for CRUD operations
- Phase 2: Drag file rows onto bundle rows for quick reassignment
- Phase 3 (future): Bulk selection and assignment

### Constraint
A file can belong to **at most one bundle** (or be unbundled). Enforced at the store level.

---

## Phase 1: Data Model & Persistence

### 1.1 Create BundleDefinition model
- [x] Create `ChezmoiSyncMonitor/Models/BundleDefinition.swift`
  - `struct BundleDefinition: Codable, Identifiable, Sendable, Equatable`
  - Properties: `id: UUID`, `name: String`, `memberPaths: [String]` (relative paths, same format as `FileStatus.path`)
  - Computed property: `isEmpty: Bool`

### 1.2 Extend CrossMachineConfig with bundles
- [x] Add `var bundles: [BundleDefinition]` to `CrossMachineConfig` in `ConfigFileStore.swift`
  - Use `decodeIfPresent` with default `[]` for backward compatibility with v1 config files
  - Bump `schemaVersion` default to 2 in `AppPreferences.defaults`
  - Validate schema version accepts both 1 and 2
- [x] Update `CrossMachineConfig.init(from prefs:)` to include bundles
- [x] Update `ConfigFileStore.merge(_:into:)` to carry bundles into `AppPreferences`

### 1.3 Add bundles to AppPreferences
- [x] Add `var bundles: [BundleDefinition] = []` to `AppPreferences`
- [x] Update `AppPreferences.defaults` to include `bundles: []`

### 1.4 Preserve bundles on preference save
- [x] **Critical integration risk**: `PreferencesStore.save(prefs:)` rewrites the config file from preferences. Ensure bundle data flows through the full save path without being dropped.
- [x] Test: save preferences, reload, verify bundles are preserved
- [x] Test: modify preferences in Settings UI, verify bundles survive the save cycle

---

## Phase 2: AppStateStore Bundle APIs

### 2.1 Bundle CRUD methods
- [x] `createBundle(name:)` — validates name is non-empty and unique (case-insensitive), creates bundle with empty memberPaths, saves config
- [x] `renameBundle(id:newName:)` — validates new name is non-empty and unique, updates name, saves config
- [x] `deleteBundle(id:)` — removes bundle from list, does NOT affect underlying files, saves config

### 2.2 Bundle membership methods
- [x] `assignFileToBundle(path:bundleId:)` — adds path to bundle's memberPaths, removes from any other bundle (one-bundle-per-file constraint), saves config
- [x] `removeFileFromBundle(path:bundleId:)` — removes path from bundle's memberPaths, does NOT untrack from chezmoi, saves config

### 2.3 Bundle query helpers
- [x] `bundleFor(path:) -> BundleDefinition?` — returns the bundle a file belongs to, or nil
- [x] `unbundledFiles(from snapshot:) -> [FileStatus]` — files not in any bundle
- [x] `bundleMembers(bundleId:from snapshot:) -> [FileStatus]` — resolves bundle member paths to FileStatus objects from current snapshot
- [x] `bundleAggregateState(bundleId:) -> FileSyncState` — worst state among members (for display color/icon)
- [x] `bundleStateCounts(bundleId:) -> [FileSyncState: Int]` — count of each state among members (for compact tags)

### 2.4 Stale membership cleanup
- [x] During refresh pipeline (after building SyncSnapshot), prune bundle member paths that are no longer tracked (file was forgotten or removed externally). Log pruned paths to activity log.

---

## Phase 3: Localization

### 3.1 Add bundle strings to Strings.swift
- [x] Add `Strings.bundles` namespace with keys for:
  - Bundle management: "New Bundle", "Rename Bundle", "Delete Bundle", "Bundle Name", etc.
  - Assignment: "Assign to Bundle...", "Remove from Bundle", "Unbundled"
  - Detail pane: empty state ("Select a bundle to see its files"), filter hint ("N files hidden by filter")
  - State tags for bundle rows
  - Confirmation dialogs for delete bundle
  - Context menu labels

### 3.2 Add corresponding entries to Localizable.strings
- [x] Add all new keys under a `// MARK: - Bundles` section

---

## Phase 4: Dashboard Two-Pane UI

### 4.1 Create BundleRowView
- [x] Create `ChezmoiSyncMonitor/UI/Dashboard/BundleRowView.swift`
  - Shows: bundle name, member count, aggregate state color indicator, compact state count tags
  - NO action buttons (bundles don't have file actions)
  - Visual distinction from file rows (e.g., folder icon, slightly different background, bold name)
  - Selected state highlight when clicked

### 4.2 Create BundleDetailView
- [x] Create `ChezmoiSyncMonitor/UI/Dashboard/BundleDetailView.swift`
  - Header: bundle name + member count + "Manage" button (rename/delete)
  - File list: reuses `FileListItemView` for each member file (with all existing action buttons/callbacks)
  - Respects current filter: only shows members matching the active filter
  - Shows hint when files are hidden by filter ("N files hidden by filter")
  - Empty state when bundle has no members or all are filtered out

### 4.3 Create BundleEmptyDetailView
- [x] Empty state view for the detail pane when no bundle is selected
  - Icon + "Select a bundle to see its files" message
  - Subtle, non-intrusive design

### 4.4 Refactor DashboardView to two-pane layout
- [x] Add `@State private var selectedBundleId: UUID?` to DashboardView
- [x] Replace the current `fileListSection` with an `HSplitView` (or custom split):
  - **Left pane (main)**:
    - Unbundled files (using existing `FileListItemView`, same action callbacks)
    - Bundle rows (using `BundleRowView`), clickable to select
    - Bundles sorted alphabetically, unbundled files sorted as currently
    - Apply current filter to both: hide all-clean bundles in "Needs Attention", hide clean unbundled files, etc.
  - **Right pane (detail)**:
    - When `selectedBundleId` is nil: `BundleEmptyDetailView`
    - When a bundle is selected: `BundleDetailView` with filtered members
- [x] Ensure all existing file action callbacks (onAdd, onApply, onDiff, onEdit, onMerge, onRevert, onForget) work identically for files in both panes
- [x] Ensure all confirmation dialogs (apply, revert, forget two-step) still work for bundle member files
- [x] Ensure drag-and-drop for adding new files still works in the main pane
- [x] Update `filteredFiles` to exclude bundled files (they appear in detail pane instead)
- [x] Increase `minWidth` from 700 to ~1000 to accommodate two panes
- [x] Clear `selectedBundleId` if the selected bundle is deleted

### 4.5 Add context menus for bundle assignment
- [x] Add context menu to `FileListItemView` (both in main pane and detail pane):
  - "Assign to Bundle >" submenu listing existing bundles (disable current bundle if already assigned)
  - "Remove from Bundle" (only shown if file is in a bundle)
  - Separator + "New Bundle..." (creates bundle and assigns file in one step)

### 4.6 Add bundle management UI
- [x] "Manage Bundles" button or menu near the filter bar:
  - "New Bundle" — text field alert/popover for name
  - Selected bundle: "Rename" option in detail pane header
  - Selected bundle: "Delete Bundle" with confirmation dialog (explains files won't be affected)

---

## Phase 5: Search & Filter Integration

### 5.1 Search across both panes
- [x] Search text filters unbundled files by path (existing behavior)
- [x] Search text also filters bundle members — bundles with zero matching members after search are hidden from main pane
- [x] Detail pane updates live as search text changes

### 5.2 Filter consistency
- [x] Verify all filter options work correctly with bundles:
  - "All": shows all unbundled files + all bundles (even all-clean)
  - "Needs Attention": hides clean unbundled files + hides all-clean bundles
  - Specific state filters (localDrift, etc.): shows only unbundled files with that state + bundles that have at least one member with that state
  - Detail pane always respects the active filter for showing members

---

## Phase 6: Polish & Edge Cases

### 6.1 Edge cases
- [x] Bundle with all members forgotten/untracked: show as empty bundle (0 files), do not auto-delete
- [x] File is forgotten via "Forget" action while in a bundle: remove from bundle membership during stale cleanup
- [x] Config file synced from another machine with different bundles: ConfigFileWatcher detects change, reloads bundles, updates UI
- [x] Bundle name validation: non-empty, trimmed, unique (case-insensitive), reasonable max length

### 6.2 Visual polish
- [x] Smooth transitions when selecting/deselecting bundles
- [x] Consistent spacing and alignment between file rows and bundle rows
- [x] Bundle row visual weight should be slightly heavier than file rows (bold name, folder icon) but not overpowering

### 6.3 Accessibility
- [x] Ensure bundle rows and detail pane are keyboard-navigable
- [x] Add accessibility labels for bundle state tags

---

## Phase 7: Version Bump & Documentation

### 7.1 Version update
- [x] Bump version to 2.0.0 in `project.yml` (major version: new UI paradigm + new feature)
- [x] Update VERSIONS.md with v2.0.0 changelog

### 7.2 Update CLAUDE.md
- [x] Add behavior invariants for bundles:
  - Deleting a bundle must NOT affect underlying files
  - Removing a file from a bundle must NOT untrack it from chezmoi
  - One-bundle-per-file constraint must be enforced at store level
  - Bundle state tags are derived, never stored
  - Stale membership cleanup runs during refresh pipeline

---

## Files to Create
- `ChezmoiSyncMonitor/Models/BundleDefinition.swift`
- `ChezmoiSyncMonitor/UI/Dashboard/BundleRowView.swift`
- `ChezmoiSyncMonitor/UI/Dashboard/BundleDetailView.swift`
- `ChezmoiSyncMonitor/UI/Dashboard/BundleEmptyDetailView.swift`

## Files to Modify
- `ChezmoiSyncMonitor/Models/AppPreferences.swift` — add bundles field
- `ChezmoiSyncMonitor/Persistence/ConfigFileStore.swift` — add bundles to CrossMachineConfig, backward compat
- `ChezmoiSyncMonitor/Persistence/PreferencesStore.swift` — preserve bundles through save cycle
- `ChezmoiSyncMonitor/State/AppStateStore.swift` — bundle CRUD, membership, query helpers, stale cleanup
- `ChezmoiSyncMonitor/UI/Dashboard/DashboardView.swift` — two-pane layout, bundle selection, context menus
- `ChezmoiSyncMonitor/UI/Dashboard/FileListItemView.swift` — add context menu for bundle assignment
- `ChezmoiSyncMonitor/Resources/Strings.swift` — bundle localization strings
- `ChezmoiSyncMonitor/Resources/Localizable.strings` — bundle string entries
- `project.yml` — version bump to 2.0.0
- `VERSIONS.md` — v2.0.0 changelog
- `CLAUDE.md` — bundle behavior invariants

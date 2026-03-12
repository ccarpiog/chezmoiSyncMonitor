## Completed (v1.5.0)

- [x] Ask for all permissions (Full Disk Access, Notifications) on first launch. Expanded onboarding permissions step to include Full Disk Access guidance with a button that opens System Settings directly to the FDA pane, alongside the existing notification permission request. Both are presented as optional but recommended.
- [x] Allow adding files using drag and drop to the dashboard when All Files is selected. Added `.onDrop` handler on the file list GroupBox that accepts file URLs, converts absolute paths to home-relative paths, and calls `addSingle()`. Shows a dashed blue border overlay when hovering. Includes hint text in the empty state.
- [x] When there is no local file, show "Local File Not Found" instead of "Local Drift". Detects chezmoi status destination char 'A' (file needs to be Added = doesn't exist locally) and sets a `localMissing` flag on `FileStatus`. The UI label conditionally shows the appropriate text.

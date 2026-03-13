- [x] Clicking on the notification should open the dashboard.
  - Done in v1.7.0: AppDelegate handles UNUserNotificationCenterDelegate, posts .openDashboard on tap. Cold-launch buffering included.

- [x] Allow setting a global keyboard shortcut to open the dashboard.
  - Done in v1.7.0: Carbon RegisterEventHotKey API with recorder UI in Settings > Advanced. Conflict detection for system shortcuts, registration failure feedback. Persisted per-machine in UserDefaults.

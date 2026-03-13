import AppKit
import UserNotifications

/// Extension defining notification names used for app-wide coordination.
extension Notification.Name {
    /// Posted to signal that the dashboard window should open.
    static let openDashboard = Notification.Name("openDashboard")
    /// Posted when the user changes the global keyboard shortcut in Preferences.
    static let dashboardShortcutChanged = Notification.Name("dashboardShortcutChanged")
}

/// App delegate that handles macOS notification tap events.
///
/// Sets itself as the `UNUserNotificationCenter` delegate so it can respond
/// when the user taps a notification. On tap, it posts an internal
/// `Notification` that the SwiftUI scene picks up to open the dashboard window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    /// Whether a notification tap occurred before the SwiftUI view subscribed.
    /// Checked once on startup to avoid missing cold-launch taps.
    var pendingDashboardOpen = false

    /// Called when the application finishes launching.
    /// Registers this delegate as the handler for user notification responses.
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Called when the user interacts with a delivered notification.
    ///
    /// Only opens the dashboard when the user taps the notification
    /// (default action). Dismiss and other actions are ignored.
    /// - Parameters:
    ///   - center: The notification center that received the response.
    ///   - response: The user's response to the notification.
    ///   - completionHandler: A closure to call when processing is complete.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            pendingDashboardOpen = true
            NotificationCenter.default.post(name: .openDashboard, object: nil)
        }
        completionHandler()
    } // End of func userNotificationCenter(_:didReceive:withCompletionHandler:)

    /// Called when a notification is about to be presented while the app is in the foreground.
    ///
    /// Returns banner and sound presentation options so notifications are still visible
    /// even when the app is active.
    /// - Parameters:
    ///   - center: The notification center.
    ///   - notification: The notification about to be delivered.
    ///   - completionHandler: A closure to call with the desired presentation options.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
} // End of class AppDelegate

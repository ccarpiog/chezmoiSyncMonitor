import Foundation
import os

/// Persists `AppPreferences` using a dual-source model:
///
/// - **Cross-machine settings** are stored in a JSON config file at
///   `~/.config/chezmoiSyncMonitor/config.json` (managed by chezmoi).
///   UserDefaults serves as a local cache for these values.
/// - **Per-machine settings** (`launchAtLogin`, `hasCompletedOnboarding`)
///   are stored only in UserDefaults.
///
/// Load priority: config file > UserDefaults > hardcoded defaults.
struct PreferencesStore: Sendable {

    /// Key prefix for all preference keys in UserDefaults.
    private static let prefix = "chezmoiSyncMonitor."

    /// Logger for preference operations.
    private static let logger = Logger(
        subsystem: "cc.carpio.ChezmoiSyncMonitor",
        category: "PreferencesStore"
    )

    /// The UserDefaults suite to use.
    private nonisolated(unsafe) let defaults: UserDefaults

    /// The config file store for cross-machine settings.
    private let configFileStore: ConfigFileStore

    /// Creates a new PreferencesStore.
    /// - Parameters:
    ///   - defaults: The UserDefaults instance to use. Defaults to `.standard`.
    ///   - configFileStore: The config file store. Defaults to a new instance.
    init(defaults: UserDefaults = .standard, configFileStore: ConfigFileStore = ConfigFileStore()) {
        self.defaults = defaults
        self.configFileStore = configFileStore
    } // End of init(defaults:configFileStore:)

    /// Saves the given preferences to both the config file (cross-machine) and UserDefaults (cache + per-machine).
    /// - Parameter prefs: The preferences to persist.
    func save(_ prefs: AppPreferences) {
        // Save cross-machine settings to config file
        do {
            try configFileStore.save(preferences: prefs)
        } catch {
            PreferencesStore.logger.warning("Failed to save config file, falling back to UserDefaults only: \(error.localizedDescription)")
        }

        // Save all settings to UserDefaults (cross-machine as cache, per-machine as primary)
        defaults.set(prefs.schemaVersion, forKey: key("schemaVersion"))
        defaults.set(prefs.pollIntervalMinutes, forKey: key("pollIntervalMinutes"))
        defaults.set(prefs.notificationsEnabled, forKey: key("notificationsEnabled"))
        defaults.set(prefs.batchSafeSyncEnabled, forKey: key("batchSafeSyncEnabled"))
        defaults.set(prefs.launchAtLogin, forKey: key("launchAtLogin"))
        defaults.set(prefs.preferredMergeTool, forKey: key("preferredMergeTool"))
        defaults.set(prefs.preferredEditor, forKey: key("preferredEditor"))
        defaults.set(prefs.chezmoiPathOverride, forKey: key("chezmoiPathOverride"))
        defaults.set(prefs.gitPathOverride, forKey: key("gitPathOverride"))
        defaults.set(prefs.sourceRepoPathOverride, forKey: key("sourceRepoPathOverride"))
        defaults.set(prefs.verboseDiagnosticsEnabled, forKey: key("verboseDiagnosticsEnabled"))

        // Persist per-machine keyboard shortcut as JSON data
        if let shortcut = prefs.dashboardShortcut,
           let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: key("dashboardShortcut"))
        } else {
            defaults.removeObject(forKey: key("dashboardShortcut"))
        }

        // Cache bundles in UserDefaults as JSON data (fallback if config file is unavailable)
        if let data = try? JSONEncoder().encode(prefs.bundles) {
            defaults.set(data, forKey: key("bundles"))
        }
    } // End of func save(_:)

    /// Loads preferences using the dual-source priority: config file > UserDefaults > hardcoded defaults.
    ///
    /// Cross-machine settings are loaded from the config file first. If the file is missing
    /// or invalid, UserDefaults is used as a fallback. Per-machine settings always come
    /// from UserDefaults.
    ///
    /// - Returns: The loaded preferences.
    func load() -> AppPreferences {
        // Load per-machine settings from UserDefaults
        let launchAtLogin: Bool
        if defaults.object(forKey: key("launchAtLogin")) != nil {
            launchAtLogin = defaults.bool(forKey: key("launchAtLogin"))
        } else {
            launchAtLogin = AppPreferences.defaults.launchAtLogin
        }

        let verboseDiagnosticsEnabled: Bool
        if defaults.object(forKey: key("verboseDiagnosticsEnabled")) != nil {
            verboseDiagnosticsEnabled = defaults.bool(forKey: key("verboseDiagnosticsEnabled"))
        } else {
            verboseDiagnosticsEnabled = AppPreferences.defaults.verboseDiagnosticsEnabled
        }

        // Per-machine: keyboard shortcut (JSON-encoded)
        var dashboardShortcut: KeyboardShortcutModel?
        if let data = defaults.data(forKey: key("dashboardShortcut")) {
            dashboardShortcut = try? JSONDecoder().decode(KeyboardShortcutModel.self, from: data)
        }

        // Try loading cross-machine settings from config file first
        if let configFilePrefs = configFileStore.load() {
            let merged = configFileStore.merge(configFilePrefs, into: AppPreferences(
                schemaVersion: configFilePrefs.schemaVersion,
                pollIntervalMinutes: configFilePrefs.pollIntervalMinutes,
                notificationsEnabled: configFilePrefs.notificationsEnabled,
                batchSafeSyncEnabled: configFilePrefs.batchSafeSyncEnabled,
                launchAtLogin: launchAtLogin,
                preferredMergeTool: configFilePrefs.preferredMergeTool,
                preferredEditor: configFilePrefs.preferredEditor,
                chezmoiPathOverride: configFilePrefs.chezmoiPathOverride,
                gitPathOverride: configFilePrefs.gitPathOverride,
                sourceRepoPathOverride: configFilePrefs.sourceRepoPathOverride,
                verboseDiagnosticsEnabled: verboseDiagnosticsEnabled,
                dashboardShortcut: dashboardShortcut,
                bundles: configFilePrefs.bundles
            ))
            return merged
        }

        // Restore bundles from UserDefaults cache (used in fallback paths below)
        var cachedBundles: [BundleDefinition] = []
        if let data = defaults.data(forKey: key("bundles")) {
            cachedBundles = (try? JSONDecoder().decode([BundleDefinition].self, from: data)) ?? []
        }

        // Fall back to UserDefaults
        guard defaults.object(forKey: key("schemaVersion")) != nil else {
            // No saved preferences at all, return defaults
            return AppPreferences(
                schemaVersion: AppPreferences.defaults.schemaVersion,
                pollIntervalMinutes: AppPreferences.defaults.pollIntervalMinutes,
                notificationsEnabled: AppPreferences.defaults.notificationsEnabled,
                batchSafeSyncEnabled: AppPreferences.defaults.batchSafeSyncEnabled,
                launchAtLogin: launchAtLogin,
                preferredMergeTool: AppPreferences.defaults.preferredMergeTool,
                preferredEditor: AppPreferences.defaults.preferredEditor,
                chezmoiPathOverride: AppPreferences.defaults.chezmoiPathOverride,
                gitPathOverride: AppPreferences.defaults.gitPathOverride,
                sourceRepoPathOverride: AppPreferences.defaults.sourceRepoPathOverride,
                verboseDiagnosticsEnabled: verboseDiagnosticsEnabled,
                dashboardShortcut: dashboardShortcut,
                bundles: cachedBundles
            )
        }

        return AppPreferences(
            schemaVersion: defaults.integer(forKey: key("schemaVersion")),
            pollIntervalMinutes: defaults.integer(forKey: key("pollIntervalMinutes")),
            notificationsEnabled: defaults.bool(forKey: key("notificationsEnabled")),
            batchSafeSyncEnabled: defaults.bool(forKey: key("batchSafeSyncEnabled")),
            launchAtLogin: launchAtLogin,
            preferredMergeTool: defaults.string(forKey: key("preferredMergeTool")),
            preferredEditor: defaults.string(forKey: key("preferredEditor")),
            chezmoiPathOverride: defaults.string(forKey: key("chezmoiPathOverride")),
            gitPathOverride: defaults.string(forKey: key("gitPathOverride")),
            sourceRepoPathOverride: defaults.string(forKey: key("sourceRepoPathOverride")),
            verboseDiagnosticsEnabled: verboseDiagnosticsEnabled,
            dashboardShortcut: dashboardShortcut,
            bundles: cachedBundles
        )
    } // End of func load()

    /// Returns whether the user has completed the first-launch onboarding.
    /// - Returns: `true` if onboarding has been completed.
    func hasCompletedOnboarding() -> Bool {
        return defaults.bool(forKey: key("hasCompletedOnboarding"))
    } // End of func hasCompletedOnboarding()

    /// Marks the first-launch onboarding as completed.
    func setOnboardingCompleted() {
        defaults.set(true, forKey: key("hasCompletedOnboarding"))
    } // End of func setOnboardingCompleted()

    /// Removes all stored preferences, resetting to defaults.
    ///
    /// Clears both UserDefaults and the config file.
    func resetAll() {
        let allKeys = [
            "schemaVersion", "pollIntervalMinutes", "notificationsEnabled",
            "batchSafeSyncEnabled", "launchAtLogin",
            "preferredMergeTool", "preferredEditor", "chezmoiPathOverride",
            "gitPathOverride", "sourceRepoPathOverride", "verboseDiagnosticsEnabled",
            "dashboardShortcut", "hasCompletedOnboarding", "bundles"
        ]
        for k in allKeys {
            defaults.removeObject(forKey: key(k))
        } // End of loop removing all preference keys

        // Write defaults to config file
        do {
            try configFileStore.save(preferences: .defaults)
        } catch {
            PreferencesStore.logger.warning("Failed to reset config file: \(error.localizedDescription)")
        }
    } // End of func resetAll()

    /// Returns the full UserDefaults key for a given preference name.
    /// - Parameter name: The short preference name.
    /// - Returns: The prefixed key string.
    private func key(_ name: String) -> String {
        return PreferencesStore.prefix + name
    } // End of func key(_:)
} // End of struct PreferencesStore

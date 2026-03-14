import Foundation
import os

/// Manages reading, writing, and watching the JSON config file at
/// `~/.config/chezmoiSyncMonitor/config.json`.
///
/// Cross-machine preferences are stored in this file so chezmoi can sync them.
/// The store watches the parent directory for changes (to handle atomic writes)
/// and debounces reloads with a 300ms window.
final class ConfigFileStore: Sendable {

    /// The default directory containing the config file.
    static let defaultConfigDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/chezmoiSyncMonitor", isDirectory: true)
    }()

    /// The default full path to the config JSON file.
    static let defaultConfigFileURL: URL = {
        defaultConfigDirectory.appendingPathComponent("config.json")
    }()

    /// The directory containing the config file (instance-level for testability).
    let configDirectory: URL

    /// The full path to the config JSON file (instance-level for testability).
    let configFileURL: URL

    /// Logger for config file operations.
    private static let logger = Logger(
        subsystem: "cc.carpio.ChezmoiSyncMonitor",
        category: "ConfigFileStore"
    )

    /// Creates a new ConfigFileStore.
    /// - Parameter directory: The directory for the config file. Defaults to `~/.config/chezmoiSyncMonitor/`.
    init(directory: URL? = nil) {
        let dir = directory ?? ConfigFileStore.defaultConfigDirectory
        self.configDirectory = dir
        self.configFileURL = dir.appendingPathComponent("config.json")
    } // End of init(directory:)

    /// The subset of `AppPreferences` that is stored in the config file (cross-machine settings).
    /// Per-machine fields (`launchAtLogin`, `hasCompletedOnboarding`) are excluded.
    struct CrossMachineConfig: Codable, Sendable, Equatable {
        var schemaVersion: Int
        var pollIntervalMinutes: Int
        var notificationsEnabled: Bool
        var batchSafeSyncEnabled: Bool
        var preferredMergeTool: String?
        var preferredEditor: String?
        var chezmoiPathOverride: String?
        var gitPathOverride: String?
        var sourceRepoPathOverride: String?
        var autoApplyRemoteEnabled: Bool
        var bundles: [BundleDefinition]

        /// Coding keys for JSON serialization.
        enum CodingKeys: String, CodingKey {
            case schemaVersion, pollIntervalMinutes, notificationsEnabled
            case batchSafeSyncEnabled, preferredMergeTool, preferredEditor
            case chezmoiPathOverride, gitPathOverride, sourceRepoPathOverride
            case autoApplyRemoteEnabled, bundles
        } // End of enum CodingKeys

        /// Custom decoder that uses `decodeIfPresent` for fields added after v1,
        /// ensuring backward compatibility with older config files.
        /// - Parameter decoder: The decoder to read data from.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            pollIntervalMinutes = try container.decode(Int.self, forKey: .pollIntervalMinutes)
            notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
            batchSafeSyncEnabled = try container.decode(Bool.self, forKey: .batchSafeSyncEnabled)
            preferredMergeTool = try container.decodeIfPresent(String.self, forKey: .preferredMergeTool)
            preferredEditor = try container.decodeIfPresent(String.self, forKey: .preferredEditor)
            chezmoiPathOverride = try container.decodeIfPresent(String.self, forKey: .chezmoiPathOverride)
            gitPathOverride = try container.decodeIfPresent(String.self, forKey: .gitPathOverride)
            sourceRepoPathOverride = try container.decodeIfPresent(String.self, forKey: .sourceRepoPathOverride)
            autoApplyRemoteEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoApplyRemoteEnabled) ?? false
            bundles = try container.decodeIfPresent([BundleDefinition].self, forKey: .bundles) ?? []
        } // End of init(from decoder:)

        /// Creates a `CrossMachineConfig` from a full `AppPreferences`, extracting only cross-machine fields.
        /// - Parameter prefs: The full preferences to extract from.
        init(from prefs: AppPreferences) {
            self.schemaVersion = prefs.schemaVersion
            self.pollIntervalMinutes = prefs.pollIntervalMinutes
            self.notificationsEnabled = prefs.notificationsEnabled
            self.batchSafeSyncEnabled = prefs.batchSafeSyncEnabled
            self.preferredMergeTool = prefs.preferredMergeTool
            self.preferredEditor = prefs.preferredEditor
            self.chezmoiPathOverride = prefs.chezmoiPathOverride
            self.gitPathOverride = prefs.gitPathOverride
            self.sourceRepoPathOverride = prefs.sourceRepoPathOverride
            self.autoApplyRemoteEnabled = prefs.autoApplyRemoteEnabled
            self.bundles = prefs.bundles
        } // End of init(from prefs:)

        /// Default cross-machine config values.
        static let defaults = CrossMachineConfig(from: .defaults)
    } // End of struct CrossMachineConfig

    /// Reads the config file and returns the parsed cross-machine config.
    ///
    /// If the file does not exist or cannot be parsed, returns `nil`.
    /// - Returns: The parsed config, or `nil` if unavailable.
    func load() -> CrossMachineConfig? {
        let fileURL = self.configFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            ConfigFileStore.logger.info("Config file does not exist at \(fileURL.path)")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let config = try decoder.decode(CrossMachineConfig.self, from: data)

            // Validate schema version
            guard config.schemaVersion >= 1 else {
                ConfigFileStore.logger.warning("Invalid schemaVersion \(config.schemaVersion) in config file")
                return nil
            }

            return config
        } catch {
            ConfigFileStore.logger.warning("Failed to parse config file: \(error.localizedDescription)")
            return nil
        }
    } // End of func load()

    /// Writes the cross-machine config to the JSON file.
    ///
    /// Creates the parent directory if it does not exist.
    /// - Parameter config: The cross-machine config to write.
    /// - Throws: File system errors if writing fails.
    func save(_ config: CrossMachineConfig) throws {
        let dirURL = self.configDirectory
        let fileURL = self.configFileURL

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: dirURL.path) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            ConfigFileStore.logger.info("Created config directory at \(dirURL.path)")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)

        ConfigFileStore.logger.info("Saved config file to \(fileURL.path)")
    } // End of func save(_:)

    /// Writes the cross-machine portion of `AppPreferences` to the config file.
    ///
    /// Convenience wrapper that extracts cross-machine fields from full preferences.
    /// - Parameter prefs: The full preferences to extract and save.
    /// - Throws: File system errors if writing fails.
    func save(preferences prefs: AppPreferences) throws {
        let config = CrossMachineConfig(from: prefs)
        try save(config)
    } // End of func save(preferences:)

    /// Merges a loaded `CrossMachineConfig` into a full `AppPreferences`,
    /// preserving per-machine fields from the existing preferences.
    ///
    /// - Parameters:
    ///   - config: The cross-machine config loaded from file.
    ///   - existing: The current full preferences (provides per-machine values).
    /// - Returns: A merged `AppPreferences` with cross-machine fields from `config`.
    func merge(_ config: CrossMachineConfig, into existing: AppPreferences) -> AppPreferences {
        var merged = existing
        merged.schemaVersion = config.schemaVersion
        merged.pollIntervalMinutes = config.pollIntervalMinutes
        merged.notificationsEnabled = config.notificationsEnabled
        merged.batchSafeSyncEnabled = config.batchSafeSyncEnabled
        merged.preferredMergeTool = config.preferredMergeTool
        merged.preferredEditor = config.preferredEditor
        merged.chezmoiPathOverride = config.chezmoiPathOverride
        merged.gitPathOverride = config.gitPathOverride
        merged.sourceRepoPathOverride = config.sourceRepoPathOverride
        merged.autoApplyRemoteEnabled = config.autoApplyRemoteEnabled
        merged.bundles = config.bundles
        return merged
    } // End of func merge(_:into:)

    /// Ensures the config file exists by writing defaults if it is missing.
    ///
    /// Called during app startup to bootstrap the config file for chezmoi management.
    /// - Parameter defaults: The default preferences to write if the file is absent.
    func ensureFileExists(defaults: AppPreferences = .defaults) {
        guard !FileManager.default.fileExists(atPath: configFileURL.path) else {
            return
        }

        do {
            try save(preferences: defaults)
            ConfigFileStore.logger.info("Bootstrapped config file with defaults")
        } catch {
            ConfigFileStore.logger.warning("Failed to bootstrap config file: \(error.localizedDescription)")
        }
    } // End of func ensureFileExists(defaults:)
} // End of class ConfigFileStore

/// Watches the config file's parent directory for changes and calls a handler when the file is modified.
///
/// Uses `DispatchSource.makeFileSystemObjectSource` on the parent directory to detect
/// atomic writes (where the file is replaced via rename). Debounces with a 300ms window.
///
/// All mutable state is accessed exclusively through `watchQueue` for thread safety.
/// `start()` and `stop()` dispatch synchronously to the queue to ensure safe access.
final class ConfigFileWatcher: @unchecked Sendable {

    /// Logger for watcher operations.
    private static let logger = Logger(
        subsystem: "cc.carpio.ChezmoiSyncMonitor",
        category: "ConfigFileWatcher"
    )

    /// The file descriptor for the watched directory. Only accessed on `watchQueue`.
    private var fileDescriptor: Int32 = -1

    /// The dispatch source monitoring file system events. Only accessed on `watchQueue`.
    private var source: DispatchSourceFileSystemObject?

    /// Debounce timer for coalescing rapid writes. Only accessed on `watchQueue`.
    private var debounceTimer: DispatchWorkItem?

    /// Debounce interval in milliseconds.
    private static let debounceMs: Int = 300

    /// The serial queue on which all mutable state is accessed.
    private let watchQueue = DispatchQueue(label: "cc.carpio.ChezmoiSyncMonitor.configWatcher")

    /// The directory to watch.
    private let watchDirectory: URL

    /// The file URL to check for existence on change events.
    private let watchFileURL: URL

    /// The handler called when the config file changes (after debounce).
    private let onChange: @Sendable () -> Void

    /// Creates a new watcher.
    /// - Parameters:
    ///   - directory: The directory to watch. Defaults to the standard config directory.
    ///   - fileURL: The file URL to check on changes. Defaults to the standard config file.
    ///   - onChange: Closure invoked when the config file changes.
    init(
        directory: URL = ConfigFileStore.defaultConfigDirectory,
        fileURL: URL = ConfigFileStore.defaultConfigFileURL,
        onChange: @escaping @Sendable () -> Void
    ) {
        self.watchDirectory = directory
        self.watchFileURL = fileURL
        self.onChange = onChange
    } // End of init(directory:fileURL:onChange:)

    /// Starts watching the config directory for write events.
    ///
    /// If the directory does not exist, it is created first.
    /// Dispatches to `watchQueue` synchronously to ensure thread-safe state access.
    func start() {
        let dirPath = watchDirectory.path

        // Ensure directory exists before watching
        if !FileManager.default.fileExists(atPath: dirPath) {
            try? FileManager.default.createDirectory(at: watchDirectory, withIntermediateDirectories: true)
        }

        watchQueue.sync { [self] in
            let fd = open(dirPath, O_EVTONLY)
            guard fd >= 0 else {
                ConfigFileWatcher.logger.warning("Failed to open config directory for watching: \(dirPath)")
                return
            }

            fileDescriptor = fd

            let dispatchSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: .write,
                queue: watchQueue
            )

            dispatchSource.setEventHandler { [weak self] in
                self?.handleDirectoryChange()
            }

            // Capture fd directly so the FD is always closed even if self is deallocated
            dispatchSource.setCancelHandler {
                close(fd)
            }

            dispatchSource.resume()
            source = dispatchSource

            ConfigFileWatcher.logger.info("Started watching config directory: \(dirPath)")
        } // End of watchQueue.sync for start
    } // End of func start()

    /// Stops watching and releases resources.
    ///
    /// Dispatches to `watchQueue` synchronously to ensure thread-safe state access.
    func stop() {
        watchQueue.sync { [self] in
            debounceTimer?.cancel()
            debounceTimer = nil
            source?.cancel()
            source = nil
            fileDescriptor = -1

            ConfigFileWatcher.logger.info("Stopped watching config directory")
        } // End of watchQueue.sync for stop
    } // End of func stop()

    /// Handles a directory change event by debouncing and then calling the onChange handler.
    /// Called on `watchQueue`.
    private func handleDirectoryChange() {
        debounceTimer?.cancel()

        let fileURL = watchFileURL
        let handler = onChange
        let workItem = DispatchWorkItem {
            // Only fire if the config file actually exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                ConfigFileWatcher.logger.info("Config file change detected, notifying handler")
                handler()
            }
        }

        debounceTimer = workItem
        watchQueue.asyncAfter(
            deadline: .now() + .milliseconds(ConfigFileWatcher.debounceMs),
            execute: workItem
        )
    } // End of func handleDirectoryChange()

    deinit {
        // Direct cleanup without queue dispatch (unsafe to dispatch in deinit)
        debounceTimer?.cancel()
        source?.cancel()
    }
} // End of class ConfigFileWatcher

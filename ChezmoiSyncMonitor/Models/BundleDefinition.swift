import Foundation

/// Defines a named group of tracked files for organizational purposes.
///
/// Bundles are an app-level concept (not a chezmoi feature) that let users
/// group files for easier triage. Stored in the cross-machine config file.
struct BundleDefinition: Codable, Identifiable, Sendable, Equatable {
    /// Unique identifier for this bundle.
    let id: UUID
    /// User-visible name of the bundle.
    var name: String
    /// Relative file paths that belong to this bundle (same format as `FileStatus.path`).
    var memberPaths: [String]

    /// Whether this bundle has no member files.
    var isEmpty: Bool { memberPaths.isEmpty }
} // End of struct BundleDefinition

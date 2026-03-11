import SwiftUI
import AppKit

/// An NSViewRepresentable that applies an AppKit tooltip to its parent view.
///
/// SwiftUI's `.help()` modifier is unreliable inside `ScrollView` + `LazyVStack`
/// hierarchies on macOS. This wrapper uses AppKit's native `toolTip` property
/// which works consistently in all container contexts.
private struct AppKitToolTip: NSViewRepresentable {
    /// The tooltip text to display on hover.
    let text: String

    /// A lightweight carrier that sets tooltip text on its superview.
    ///
    /// Using an overlay view directly can intercept mouse events and make
    /// controls unresponsive. Applying the tooltip to the parent view avoids
    /// hit-testing issues.
    private final class ToolTipCarrierView: NSView {
        var text: String = "" {
            didSet { applyToParent() }
        }

        /// Always pass pointer events through to underlying controls.
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            applyToParent()
        }

        private func applyToParent() {
            superview?.toolTip = text
        }
    } // End of class ToolTipCarrierView

    /// Creates a lightweight carrier view.
    func makeNSView(context: Context) -> NSView {
        let view = ToolTipCarrierView(frame: .zero)
        view.text = text
        return view
    } // End of func makeNSView(context:)

    /// Updates the tooltip text when the SwiftUI state changes.
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ToolTipCarrierView)?.text = text
    } // End of func updateNSView(_:context:)

    /// Clears tooltip text when this modifier is removed.
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        guard let carrier = nsView as? ToolTipCarrierView else { return }
        if carrier.superview?.toolTip == carrier.text {
            carrier.superview?.toolTip = nil
        }
    } // End of static func dismantleNSView(_:coordinator:)
} // End of struct AppKitToolTip

extension View {
    /// Adds a native macOS tooltip that appears on hover.
    ///
    /// Unlike SwiftUI's `.help()`, this modifier uses AppKit's `toolTip` property
    /// and works reliably inside `ScrollView`, `LazyVStack`, and other containers
    /// where `.help()` may be ignored.
    ///
    /// - Parameter text: The tooltip string to show on hover.
    /// - Returns: A view with an AppKit tooltip attached to its host view.
    func toolTip(_ text: String) -> some View {
        background(AppKitToolTip(text: text))
    } // End of func toolTip(_:)
} // End of View extension

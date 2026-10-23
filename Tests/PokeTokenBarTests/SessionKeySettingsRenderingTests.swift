import AppKit
import SwiftUI
import XCTest
@testable import PokeTokenBar

/// Used for the optional keyboard-focus check on an interactive desktop.
private final class SessionKeyTestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class SessionKeySettingsRenderingTests: XCTestCase {
    func testSessionKeyEntryOpensInsideViewportAndPreservesDifficultyControls() async throws {
        let suite = "SessionKeySettingsRendering-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        let companion = CompanionStore(fileURL: file, defaults: defaults)
        let navigation = PopoverNavigation()
        navigation.openSessionKeySettings()
        let host = NSHostingController(rootView: SettingsView(
            onClose: {}, onChooseRepresentative: {}, startExpanded: navigation.expandAdvancedOnOpen)
            .environment(usage).environment(companion)
            .frame(width: PopoverMetrics.width))
        let previousKeyWindow = NSApp.keyWindow
        let window = SessionKeyTestWindow(contentRect: NSRect(x: -10000, y: -10000, width: PopoverMetrics.width, height: 460),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        defer {
            window.orderOut(nil)
            previousKeyWindow?.makeKey()
        }
        host.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        host.view.layoutSubtreeIfNeeded()
        let views = descendants(of: host.view)
        let secure = try XCTUnwrap(views.compactMap { $0 as? NSSecureTextField }.first)
        let rect = secure.convert(secure.bounds, to: host.view)
        XCTAssertTrue(host.view.bounds.contains(rect), "session key entry must be visible after scrolling")
        // Hosted CI renders the layout but does not grant this XCTest window an editor.
        // Verify keyboard focus on an interactive Mac with PTB_VERIFY_KEYBOARD_FOCUS=1.
        if ProcessInfo.processInfo.environment["PTB_VERIFY_KEYBOARD_FOCUS"] == "1" {
            XCTAssertNotNil(secure.currentEditor(), "session key entry must receive keyboard focus")
            XCTAssertTrue(secure.currentEditor() === window.firstResponder)
        }
        // Since macOS 27 a SwiftUI Slider has no NSSlider behind it, and the grouped Form does not draw into
        // a cached bitmap, so neither the view tree nor rendered text can count the controls. Check the
        // composition instead: Settings' static body type names every view it builds (opaque types resolve).
        XCTAssertTrue(String(reflecting: SettingsView.Body.self).contains("DifficultySettingsSection"),
                      "growth and shop difficulty controls must survive the Settings merge")
        XCTAssertTrue(String(reflecting: DifficultySettingsSection.Body.self).contains("SwiftUI.Slider"))
        XCTAssertTrue(navigation.showSettings)
        navigation.reset()
        XCTAssertFalse(navigation.expandAdvancedOnOpen)
    }

    private func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }
}

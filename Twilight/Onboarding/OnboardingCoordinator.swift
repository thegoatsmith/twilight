import AppKit
import SwiftUI

/// Owns the lifecycle of the first-run onboarding window. Hosted by the App
/// via `@NSApplicationDelegateAdaptor` so we can act at
/// `applicationDidFinishLaunching` — the menu-bar-only app has no main window
/// scene whose `.onAppear` we could hang this off.
final class OnboardingCoordinator: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private let prefs = PreferencesStore()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !prefs.didFinishOnboarding else { return }
        present()
    }

    private func present() {
        let host = NSHostingController(rootView: OnboardingView(onFinish: { [weak self] in
            self?.finish()
        }))
        let win = NSWindow(contentViewController: host)
        win.styleMask = [.titled, .closable]
        win.title = "Welcome to Twilight"
        win.isReleasedWhenClosed = false
        win.center()
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    private func finish() {
        prefs.didFinishOnboarding = true
        window?.close()
        window = nil
    }

    // Treat a manual close (red button) as completed too — otherwise the
    // window would reappear every launch.
    func windowWillClose(_ notification: Notification) {
        prefs.didFinishOnboarding = true
        window = nil
    }
}

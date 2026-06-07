import AdminDocCore
import AppKit
import SwiftUI

@main
struct AdminDocApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DiagnosticStore()

    var body: some Scene {
        WindowGroup("AdminDoc") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(L10n.string("diagnostics.run.command")) {
                    Task { await store.runDiagnostics() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        bringAdminDocForward()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.bringAdminDocForward()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.bringAdminDocForward()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringAdminDocForward()
        return true
    }

    private func bringAdminDocForward() {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)

        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

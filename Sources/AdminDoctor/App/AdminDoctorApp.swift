import AdminDoctorCore
import AppKit
import SwiftUI

@main
struct AdminDoctorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DiagnosticStore()

    var body: some Scene {
        WindowGroup("AdminDoctor") {
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
        bringAdminDoctorForward()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.bringAdminDoctorForward()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.bringAdminDoctorForward()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringAdminDoctorForward()
        return true
    }

    private func bringAdminDoctorForward() {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)

        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

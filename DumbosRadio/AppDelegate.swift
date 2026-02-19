import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        NotificationManager.requestPermission()

        // Set up Now Playing remote commands
        // Note: RadioPlayer is set up in the App struct; this call is handled there
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in background when window is closed (menu bar mode)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Re-open main window when dock icon is clicked
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

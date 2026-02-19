import UserNotifications
import AppKit

struct NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyStationChanged(_ station: Station) {
        let content = UNMutableNotificationContent()
        content.title = "Now Playing"
        content.body = station.name
        if !station.metaString.isEmpty {
            content.subtitle = station.metaString
        }

        let request = UNNotificationRequest(
            identifier: "station-changed",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

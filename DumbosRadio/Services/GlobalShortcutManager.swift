import AppKit
import Combine

/// Manages a system-wide play/stop hotkey (⌃⌥⌘P) using NSEvent global monitoring.
/// Requires Accessibility permission — monitors that permission and installs/removes
/// the event tap automatically as permission and the enabled flag change.
@MainActor
final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var monitor: Any?
    private weak var player: RadioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var pollTask: Task<Void, Never>?

    // MARK: - Setup

    func setup(player: RadioPlayer, persistence: PersistenceManager) {
        self.player = player

        persistence.$globalShortcutsEnabled
            .sink { [weak self] enabled in self?.setEnabled(enabled) }
            .store(in: &cancellables)

        setEnabled(persistence.globalShortcutsEnabled)
    }

    // MARK: - Enable / disable

    func setEnabled(_ enabled: Bool) {
        stopPolling()
        removeMonitor()
        guard enabled else { return }

        if AXIsProcessTrusted() {
            installMonitor()
        } else {
            // Poll until the user grants access in System Settings
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, !Task.isCancelled else { return }
                    if AXIsProcessTrusted() {
                        self.stopPolling()
                        self.installMonitor()
                        return
                    }
                }
            }
        }
    }

    // MARK: - Monitor

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ⌃⌥⌘P
            let required: NSEvent.ModifierFlags = [.control, .option, .command]
            guard event.modifierFlags.intersection([.control, .option, .command, .shift]) == required,
                  event.charactersIgnoringModifiers?.lowercased() == "p"
            else { return }
            Task { @MainActor [weak self] in
                self?.player?.togglePlayStop()
            }
        }
    }

    private func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Accessibility helpers

    var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

import Carbon
import Cocoa

final class SecureInputDetector {
    var onChange: ((Bool) -> Void)?
    private(set) var isActive = false
    private var isMonitoring = false
    private var timer: Timer?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appChanged),
                           name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appChanged),
                           name: NSWorkspace.didDeactivateApplicationNotification, object: nil)

        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.check()
        }

        check()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func check() {
        let active = IsSecureEventInputEnabled()
        guard active != isActive else { return }
        isActive = active
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onChange?(self.isActive)
        }
    }

    @objc private func appChanged(_: Notification) {
        check()
    }

    deinit {
        stopMonitoring()
    }
}

import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    static let shared = LaunchAtLoginController()

    @Published private(set) var isEnabled = false
    @Published var lastError: String?
    @Published private(set) var needsApproval = false

    private init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
        if status == .enabled {
            lastError = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
            if enabled && needsApproval {
                lastError = "Allow Calendar Airplane in System Settings → General → Login Items & Extensions."
            }
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }
}

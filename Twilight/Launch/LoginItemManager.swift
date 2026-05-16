import Foundation
import ServiceManagement

public final class LoginItemManager {

    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
            return true
        } catch {
            NSLog("LoginItemManager: setEnabled(\(enabled)) failed: \(error)")
            return false
        }
    }
}

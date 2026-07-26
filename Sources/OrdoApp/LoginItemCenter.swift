// OrdoApp — LoginItemCenter: launch-at-login via SMAppService (ARCHITECTURE §6.4).
// Acts only once launchAtLoginConsented is true (§4.2 — default ON with consent).
// SMAppService works only from a signed bundle; under `swift run` it throws (degrades silently).

import Foundation
import ServiceManagement
import os

@MainActor
final class LoginItemCenter {

    private static let log = Logger(subsystem: "com.ordo.app", category: "LoginItem")

    /// Register or unregister the login item to match the desired state. No-op until
    /// the user has consented. Any failure (e.g. running unbundled) is swallowed.
    func sync(enabled: Bool, consented: Bool) {
        guard consented else { return }
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
        } catch {
            // Unbundled (swift run) or a transient failure — degrade silently.
            Self.log.info("SMAppService sync skipped: \(error.localizedDescription, privacy: .public)")
        }
    }
}

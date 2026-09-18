import AppKit
import ServiceManagement

@MainActor
final class TimeZoneAuthorization {
    private let service = SMAppService.daemon(plistName: "com.yongtian.DateDay.TimeZoneHelper.plist")

    func change(to identifier: String) async throws {
        // An absent daemon can report notFound before it has a BTM record.
        // Register it first instead of mistaking that status for missing approval.
        if service.status != .enabled {
            do { try service.register() }
            catch {
                if service.status != .requiresApproval && service.status != .enabled {
                    throw error
                }
            }
        }
        guard service.status == .enabled || service.status == .requiresApproval else {
            throw NSError(domain: "DateDay.Helper", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "macOS could not register the Date Day time-zone helper (status \(service.status.rawValue)). This is a helper installation error, not a missing approval."
            ])
        }
        guard service.status == .enabled else {
            SMAppService.openSystemSettingsLoginItems()
            throw NSError(domain: "DateDay.Helper", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Allow Date Day in Login Items & Extensions to enable time-zone changes. macOS requires administrator approval once. Then select the clock again."
            ])
        }
        try await send(identifier)
    }

    private func send(_ identifier: String) async throws {
        let connection = NSXPCConnection(
            machServiceName: TimeZoneHelperIdentity.service, options: .privileged
        )
        connection.setCodeSigningRequirement(
            TimeZoneHelperIdentity.requirement(identifier: TimeZoneHelperIdentity.service)
        )
        connection.remoteObjectInterface = NSXPCInterface(with: TimeZoneHelperProtocol.self)
        let reply = HelperReply()
        defer { connection.invalidate() }
        try await withCheckedThrowingContinuation { continuation in
            reply.continuation = continuation
            let fail: @Sendable () -> Void = {
                Task { @MainActor in
                    reply.finish("The time-zone helper is unavailable. Check Date Day in Login Items & Extensions.")
                }
            }
            connection.interruptionHandler = fail
            connection.invalidationHandler = fail
            connection.resume()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in fail() }) as? TimeZoneHelperProtocol else {
                fail()
                return
            }
            proxy.setTimeZone(identifier) { message in
                Task { @MainActor in reply.finish(message) }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                reply.finish("The time-zone helper did not respond in time. Check the current system time zone before trying again.")
            }
        }
    }
}

@MainActor
private final class HelperReply {
    var continuation: CheckedContinuation<Void, Error>?
    func finish(_ message: String?) {
        guard let continuation else { return }
        self.continuation = nil
        if let message {
            continuation.resume(throwing: NSError(
                domain: "DateDay.Helper", code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        } else {
            continuation.resume()
        }
    }
}

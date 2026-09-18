import Foundation
import SystemConfiguration

final class TimeZoneHelper: NSObject, NSXPCListenerDelegate, TimeZoneHelperProtocol {
    private let queue = DispatchQueue(label: "DateDay.TimeZoneChanges")

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        var consoleUID: uid_t = 0
        guard SCDynamicStoreCopyConsoleUser(nil, &consoleUID, nil) != nil,
              consoleUID != 0, connection.effectiveUserIdentifier == consoleUID else { return false }
        connection.setCodeSigningRequirement(
            TimeZoneHelperIdentity.requirement(identifier: "com.yongtian.DateDay")
        )
        connection.exportedInterface = NSXPCInterface(with: TimeZoneHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func setTimeZone(_ identifier: String, withReply reply: @escaping (String?) -> Void) {
        guard TimeZone.knownTimeZoneIdentifiers.contains(identifier) else {
            reply("Invalid time zone.")
            return
        }
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/systemsetup")
            process.arguments = ["-settimezone", identifier]
            // No shell or caller-supplied executable is accepted.
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                NSTimeZone.resetSystemTimeZone()
                guard TimeZone.current.identifier == identifier else {
                    reply("macOS did not retain the requested time zone. Check automatic time-zone selection in System Settings.")
                    return
                }
                reply(nil)
            } catch {
                reply(error.localizedDescription)
            }
        }
    }
}

let delegate = TimeZoneHelper()
let listener = NSXPCListener(machServiceName: TimeZoneHelperIdentity.service)
listener.setConnectionCodeSigningRequirement(
    TimeZoneHelperIdentity.requirement(identifier: "com.yongtian.DateDay")
)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()

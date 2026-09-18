import Foundation

@objc protocol TimeZoneHelperProtocol {
    func setTimeZone(_ identifier: String, withReply reply: @escaping (String?) -> Void)
}

enum TimeZoneHelperIdentity {
    static let service = "com.yongtian.DateDay.TimeZoneHelper"
    static let team = "CS276L7FX7"
    static func requirement(identifier: String) -> String {
        "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }
}

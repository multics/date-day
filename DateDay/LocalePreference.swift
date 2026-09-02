import Foundation

extension Notification.Name {
    static let dateDayLocalePreferenceDidChange = Notification.Name(
        "DateDayLocalePreferenceDidChange"
    )
}

@MainActor
enum LocalePreference {
    struct Option {
        let identifier: String?
        let title: String
    }

    static let options = [
        Option(identifier: nil, title: "System Default"),
        Option(identifier: "en_US", title: "English (United States)"),
        Option(identifier: "en_GB", title: "English (United Kingdom)"),
        Option(identifier: "zh_CN", title: "简体中文"),
        Option(identifier: "zh_TW", title: "繁體中文"),
    ]

    private static let defaultsKey = "localeOverride"

    static var selectedIdentifier: String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    static var currentLocale: Locale {
        guard let selectedIdentifier else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: selectedIdentifier)
    }

    static func select(_ identifier: String?) {
        if let identifier {
            UserDefaults.standard.set(identifier, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }

        NotificationCenter.default.post(
            name: .dateDayLocalePreferenceDidChange,
            object: nil
        )
    }
}

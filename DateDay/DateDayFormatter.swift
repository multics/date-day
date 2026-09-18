import Foundation

enum DateDayFormatter {
    static func components(
        for date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> (weekday: String, date: String) {
        if locale.language.languageCode?.identifier == "zh" {
            return chineseComponents(for: date, timeZone: timeZone)
        }

        let weekday = formatter(
            locale: locale,
            timeZone: timeZone,
            template: "EEE"
        ).string(from: date)
        let numericDate = formatter(
            locale: locale,
            timeZone: timeZone,
            template: "d"
        ).string(from: date)
        return (weekday, numericDate)
    }

    static func string(
        for date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let components = components(
            for: date,
            locale: locale,
            timeZone: timeZone
        )
        return "\(components.weekday) \(components.date)"
    }

    static func timeString(
        for date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func chineseComponents(
        for date: Date,
        timeZone: TimeZone
    ) -> (weekday: String, date: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = weekdaySymbols[calendar.component(.weekday, from: date) - 1]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "d"

        return (weekday, dateFormatter.string(from: date))
    }

    private static func formatter(
        locale: Locale,
        timeZone: TimeZone,
        template: String
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

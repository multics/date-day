import Foundation

enum DateDayFormatter {
    static func string(
        for date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        if locale.language.languageCode?.identifier == "zh" {
            return chineseString(for: date, timeZone: timeZone)
        }

        let weekday = formatter(
            locale: locale,
            timeZone: timeZone,
            template: "EEE"
        ).string(from: date)
        let numericDate = formatter(
            locale: locale,
            timeZone: timeZone,
            template: "yMd"
        ).string(from: date)

        return "\(weekday) \(numericDate)"
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

    private static func chineseString(
        for date: Date,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = weekdaySymbols[calendar.component(.weekday, from: date) - 1]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return "\(weekday) \(dateFormatter.string(from: date))"
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

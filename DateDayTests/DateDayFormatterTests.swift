import Foundation
import Testing

struct DateDayFormatterTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test
    func formatsUSEnglish() {
        #expect(
            formatted(localeIdentifier: "en_US") == "Thu 31"
        )
    }

    @Test
    func respectsBritishDateOrder() {
        #expect(
            formatted(localeIdentifier: "en_GB") == "Thu 31"
        )
    }

    @Test
    func separatesWeekdayAndDateForStackedRendering() {
        let components = DateDayFormatter.components(
            for: testDate,
            locale: Locale(identifier: "en_US"),
            timeZone: utc
        )

        #expect(components.weekday == "Thu")
        #expect(components.date == "31")
    }

    @Test(arguments: ["zh_CN", "zh_TW", "zh_HK"])
    func usesCompactChineseFormat(localeIdentifier: String) {
        #expect(
            formatted(localeIdentifier: localeIdentifier) == "四 31"
        )
    }

    @Test
    func formatsWorldClockTimes() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = utc
        components.year = 2026
        components.month = 9
        components.day = 2
        components.hour = 9
        components.minute = 6
        let date = components.date!
        let locale = Locale(identifier: "en_US")

        #expect(DateDayFormatter.timeString(
            for: date,
            locale: locale,
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        ) == "17:06")
        #expect(DateDayFormatter.timeString(
            for: date,
            locale: locale,
            timeZone: TimeZone(identifier: "America/Los_Angeles")!
        ) == "02:06")
        #expect(DateDayFormatter.timeString(
            for: date,
            locale: locale,
            timeZone: utc
        ) == "09:06")
    }

    private func formatted(localeIdentifier: String) -> String {
        DateDayFormatter.string(
            for: testDate,
            locale: Locale(identifier: localeIdentifier),
            timeZone: utc
        )
    }

    private var testDate: Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = utc
        components.year = 2026
        components.month = 12
        components.day = 31
        components.hour = 12

        return components.date!
    }
}

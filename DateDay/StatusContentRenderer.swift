import AppKit

@MainActor
enum StatusContentRenderer {
    private struct ClockText {
        let label: String
        let time: String
        let labelFont: NSFont
        let timeFont: NSFont
        let isCurrentTimeZone: Bool
        let width: CGFloat
    }

    static func image(
        date: Date,
        locale: Locale,
        clocks: [WorldClockConfiguration],
        weather: WeatherSnapshot?
    ) -> NSImage {
        let height: CGFloat = 30
        let dateComponents = DateDayFormatter.components(
            for: date,
            locale: locale,
            timeZone: .autoupdatingCurrent
        )
        let dateTopFont = NSFont.systemFont(ofSize: 10, weight: .regular)
        let dateBottomFont = NSFont.monospacedDigitSystemFont(
            ofSize: 9,
            weight: .regular
        )
        let dateWidth = ceil(max(
            textWidth(dateComponents.weekday, font: dateTopFont),
            textWidth(dateComponents.date, font: dateBottomFont)
        ))

        let clockText = clocks.enumerated().map { index, clock in
            let isCurrentTimeZone = clock.timeZoneIdentifier
                == TimeZone.autoupdatingCurrent.identifier
            let weight: NSFont.Weight = if isCurrentTimeZone {
                .bold
            } else if index == 2 {
                .thin
            } else {
                .regular
            }
            let labelFont = NSFont.systemFont(
                ofSize: 10,
                weight: weight
            )
            let timeFont = NSFont.monospacedDigitSystemFont(
                ofSize: 9,
                weight: weight
            )
            let time = DateDayFormatter.timeString(
                for: date,
                locale: locale,
                timeZone: clock.timeZone
            )
            let width = max(
                min(56, ceil(textWidth(clock.label, font: labelFont))),
                ceil(textWidth(time, font: timeFont))
            )
            return ClockText(
                label: clock.label,
                time: time,
                labelFont: labelFont,
                timeFont: timeFont,
                isCurrentTimeZone: isCurrentTimeZone,
                width: width
            )
        }

        let weatherTopFont = NSFont.monospacedDigitSystemFont(
            ofSize: 9,
            weight: .thin
        )
        let weatherBottomFont = NSFont.monospacedDigitSystemFont(
            ofSize: 9,
            weight: .thin
        )
        let weatherNumberWidth = weather.map {
            ceil(max(
                textWidth($0.celsiusValueText, font: weatherTopFont),
                textWidth($0.fahrenheitValueText, font: weatherBottomFont)
            ))
        } ?? 0
        let weatherUnitWidth = weather.map { _ in
            ceil(max(
                textWidth("°C", font: weatherTopFont),
                textWidth("°F", font: weatherBottomFont)
            ))
        } ?? 0
        let weatherWidth = weatherNumberWidth + weatherUnitWidth
        let weatherIcon = weather.flatMap { snapshot in
            NSImage(
                systemSymbolName: snapshot.conditionSymbolName,
                accessibilityDescription: snapshot.conditionDescription
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            )
        }
        weatherIcon?.isTemplate = true
        let weatherIconWidth: CGFloat = weather == nil ? 0 : 18

        let topLineHeight = ceil([
            textHeight(dateComponents.weekday, font: dateTopFont),
            weather.map { textHeight($0.celsiusText, font: weatherTopFont) } ?? 0,
            clockText.map { textHeight($0.label, font: $0.labelFont) }.max() ?? 0,
        ].max() ?? 0)
        let bottomLineHeight = ceil([
            textHeight(dateComponents.date, font: dateBottomFont),
            weather.map {
                textHeight($0.fahrenheitText, font: weatherBottomFont)
            } ?? 0,
            clockText.map { textHeight($0.time, font: $0.timeFont) }.max() ?? 0,
        ].max() ?? 0)
        let lineGap: CGFloat = 1
        let stackedContentHeight = topLineHeight + lineGap + bottomLineHeight
        let bottomLineY = floor((height - stackedContentHeight) / 2)
        let topLineY = bottomLineY + bottomLineHeight + lineGap
        let topReferenceHeight = clockText.last.map {
            textHeight($0.label, font: $0.labelFont)
        } ?? textHeight(dateComponents.weekday, font: dateTopFont)
        let celsiusVerticalOffset = weather.map {
            textHeight($0.celsiusText, font: weatherTopFont)
                - topReferenceHeight
        } ?? 0
        let fahrenheitVerticalOffset: CGFloat = 0

        let itemGap: CGFloat = 1
        let separatorFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let separatorWidth = clockText.isEmpty ? 0 : ceil(textWidth("·", font: separatorFont))
        let clockWidth = clockText.reduce(0) { $0 + $1.width }
        let clockSpacing = CGFloat(max(0, clockText.count - 1)) * itemGap
        let dateSpacing = clockText.isEmpty
            ? (weather == nil ? 0 : itemGap)
            : itemGap + separatorWidth + itemGap
        let weatherSpacing = weather != nil && !clockText.isEmpty ? itemGap : 0
        let temperatureSpacing = weather == nil ? 0 : itemGap
        let width = dateWidth + dateSpacing + clockWidth + clockSpacing
            + weatherSpacing + weatherIconWidth + temperatureSpacing
            + weatherWidth
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0

            drawCentered(
                dateComponents.weekday,
                font: dateTopFont,
                in: NSRect(
                    x: x,
                    y: topLineY,
                    width: dateWidth,
                    height: topLineHeight
                )
            )
            drawCentered(
                dateComponents.date,
                font: dateBottomFont,
                in: NSRect(
                    x: x,
                    y: bottomLineY,
                    width: dateWidth,
                    height: bottomLineHeight
                )
            )
            x += dateWidth

            if !clockText.isEmpty {
                x += itemGap
                let separatorHeight = textHeight("·", font: separatorFont)
                drawCentered(
                    "·",
                    font: separatorFont,
                    in: NSRect(
                        x: x,
                        y: (height - separatorHeight) / 2,
                        width: separatorWidth,
                        height: separatorHeight
                    )
                )
                x += separatorWidth + itemGap
            } else if weather != nil {
                x += itemGap
            }

            for (index, clock) in clockText.enumerated() {
                drawCentered(
                    clock.label,
                    font: clock.labelFont,
                    in: NSRect(
                        x: x,
                        y: topLineY,
                        width: clock.width,
                        height: topLineHeight
                    )
                )
                drawCenteredTime(
                    clock.time,
                    font: clock.timeFont,
                    showsColon: !clock.isCurrentTimeZone
                        || Int(date.timeIntervalSinceReferenceDate) % 2 == 0,
                    in: NSRect(
                        x: x,
                        y: bottomLineY,
                        width: clock.width,
                        height: bottomLineHeight
                    )
                )
                x += clock.width
                if index < clockText.count - 1 {
                    x += itemGap
                }
            }

            if let weather {
                if !clockText.isEmpty {
                    x += itemGap
                }
                if let weatherIcon, weatherIcon.size.width > 0,
                    weatherIcon.size.height > 0
                {
                    let iconRect = NSRect(
                        x: x,
                        y: floor((height - 16) / 2),
                        width: weatherIconWidth,
                        height: 16
                    )
                    let scale = min(
                        iconRect.width / weatherIcon.size.width,
                        iconRect.height / weatherIcon.size.height
                    )
                    let drawSize = NSSize(
                        width: weatherIcon.size.width * scale,
                        height: weatherIcon.size.height * scale
                    )
                    weatherIcon.draw(
                        in: NSRect(
                            x: iconRect.midX - drawSize.width / 2,
                            y: iconRect.midY - drawSize.height / 2,
                            width: drawSize.width,
                            height: drawSize.height
                        )
                    )
                }
                x += weatherIconWidth + itemGap
                drawTemperature(
                    value: weather.celsiusValueText,
                    unit: "°C",
                    font: weatherTopFont,
                    numberWidth: weatherNumberWidth,
                    unitWidth: weatherUnitWidth,
                    in: NSRect(
                        x: x,
                        y: topLineY + celsiusVerticalOffset,
                        width: weatherWidth,
                        height: topLineHeight
                    )
                )
                drawTemperature(
                    value: weather.fahrenheitValueText,
                    unit: "°F",
                    font: weatherBottomFont,
                    numberWidth: weatherNumberWidth,
                    unitWidth: weatherUnitWidth,
                    in: NSRect(
                        x: x,
                        y: bottomLineY + fahrenheitVerticalOffset,
                        width: weatherWidth,
                        height: bottomLineHeight
                    )
                )
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        text.size(withAttributes: [.font: font]).width
    }

    private static func textHeight(_ text: String, font: NSFont) -> CGFloat {
        text.size(withAttributes: [.font: font]).height
    }

    private static func drawCentered(
        _ text: String,
        font: NSFont,
        in rect: NSRect
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        text.draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph,
            ]
        )
    }

    private static func drawTemperature(
        value: String,
        unit: String,
        font: NSFont,
        numberWidth: CGFloat,
        unitWidth: CGFloat,
        in rect: NSRect
    ) {
        let numberParagraph = NSMutableParagraphStyle()
        numberParagraph.alignment = .right
        value.draw(
            in: NSRect(
                x: rect.minX,
                y: rect.minY,
                width: numberWidth,
                height: rect.height
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: numberParagraph,
            ]
        )

        let unitParagraph = NSMutableParagraphStyle()
        unitParagraph.alignment = .left
        unit.draw(
            in: NSRect(
                x: rect.minX + numberWidth,
                y: rect.minY,
                width: unitWidth,
                height: rect.height
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: unitParagraph,
            ]
        )
    }

    private static func drawCenteredTime(
        _ text: String,
        font: NSFont,
        showsColon: Bool,
        in rect: NSRect
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph,
            ]
        )

        if !showsColon {
            let colonRange = (text as NSString).range(of: ":")
            if colonRange.location != NSNotFound {
                attributedText.addAttribute(
                    .foregroundColor,
                    value: NSColor.clear,
                    range: colonRange
                )
            }
        }
        attributedText.draw(in: rect)
    }
}

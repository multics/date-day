import AppKit

@MainActor
enum StatusContentRenderer {
    private struct ClockText {
        let label: String
        let time: String
        let labelFont: NSFont
        let timeFont: NSFont
        let width: CGFloat
    }

    static func image(
        date: Date,
        locale: Locale,
        clocks: [WorldClockConfiguration]
    ) -> NSImage {
        let dateText = DateDayFormatter.string(
            for: date,
            locale: locale,
            timeZone: .autoupdatingCurrent
        )
        let dateFont = NSFont.menuBarFont(ofSize: 13)
        let dateWidth = textWidth(dateText, font: dateFont)

        let clockText = clocks.map { clock in
            let labelFont = NSFont.systemFont(
                ofSize: 10,
                weight: clock.isSystemTimeZone ? .bold : .regular
            )
            let timeFont = NSFont.monospacedDigitSystemFont(
                ofSize: 9,
                weight: clock.isSystemTimeZone ? .bold : .regular
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
                width: width
            )
        }

        let clockGap: CGFloat = 1
        let dateGap: CGFloat = 1
        let clockWidth = clockText.reduce(0) { $0 + $1.width }
        let clockSpacing = CGFloat(max(0, clockText.count - 1)) * clockGap
        let dateSpacing = clockText.isEmpty ? 0 : dateGap
        let width = clockWidth + clockSpacing + dateSpacing + dateWidth
        let height: CGFloat = 30
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0

            for (index, clock) in clockText.enumerated() {
                let labelHeight = ceil(textHeight(clock.label, font: clock.labelFont))
                let timeHeight = ceil(textHeight(clock.time, font: clock.timeFont))
                let lineGap: CGFloat = 1
                let contentHeight = labelHeight + lineGap + timeHeight
                let bottomPadding = floor((height - contentHeight) / 2)

                drawCentered(
                    clock.label,
                    font: clock.labelFont,
                    in: NSRect(
                        x: x,
                        y: bottomPadding + timeHeight + lineGap,
                        width: clock.width,
                        height: labelHeight
                    )
                )
                drawCentered(
                    clock.time,
                    font: clock.timeFont,
                    in: NSRect(
                        x: x,
                        y: bottomPadding,
                        width: clock.width,
                        height: timeHeight
                    )
                )
                x += clock.width
                if index < clockText.count - 1 {
                    x += clockGap
                }
            }

            if !clockText.isEmpty {
                x += dateGap
            }

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: NSColor.black,
            ]
            let dateSize = dateText.size(withAttributes: dateAttributes)
            dateText.draw(
                at: NSPoint(x: x, y: floor((height - dateSize.height) / 2)),
                withAttributes: dateAttributes
            )
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
}

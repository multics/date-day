<p align="center">
  <img src="DateDay/Assets.xcassets/AppIcon.appiconset/AppIcon-128@2x.png"
       width="128" height="128" alt="Date Day app icon">
</p>

# Date Day

Date Day is a menu-bar app for macOS 26 or later. It shows the current weekday
and date. It can also show up to three clocks for selected time zones.

Date Day follows the system locale by default. You can select a different
locale in the app settings.

Date Day can also show the current temperature in both Celsius and Fahrenheit.
Weather is optional and is off by default.

Examples:

- US English: `Thu` above `31`
- British English: `Thu` above `31`
- Chinese: `四` above `31`

## Features

- Display a locale-aware weekday above the date in the menu bar.
- Override the system locale with US English, British English, Simplified
  Chinese, or Traditional Chinese.
- Show one to three clocks after the date, followed by the temperature.
- Configure up to three clocks with stable time zones and custom labels.
- Move clocks that match the Mac system time zone to the first position, while
  keeping the configured order for the other clocks.
- Show matching clocks in bold and blink their colons.
- Click a clock entry in the menu to set the Mac system time zone.
  Entries follow the menu-bar order. The current zone is disabled; other zones
  are selectable. Approve the Date Day helper in macOS
  Login Items & Extensions on first use. Later selections change the time zone
  directly, without a password or Touch ID prompt from Date Day.
  Automatic time-zone selection in System Settings can override a manual change.
- Use thin text for the third displayed clock.
- Start the app when you log in.
- Show Celsius and Fahrenheit together in a compact menu-bar block.
- Show a familiar condition icon between the clocks and temperatures.
- Use the Mac location or a manually selected city for weather.
- Refresh weather every 5, 10, 30, or 60 minutes and retain the last successful
  reading when the network is unavailable.

Date Day uses the Gregorian calendar. Chinese locales use a compact,
one-character weekday.

Weather data is provided by [Open-Meteo](https://open-meteo.com/). Automatic
location uses city-level accuracy, and coordinates are rounded before they are
sent to the weather service. Date Day requests location access only after you
enable weather with Automatic Location.

## Requirements

- macOS 26 or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build and run

Time-zone switching requires a signed app and helper. The helper accepts only
Date Day signed by team `CS276L7FX7`. For a fork, change the team identifier in
`Shared/TimeZoneHelperProtocol.swift` to your own team and sign both targets
with that team. Ad-hoc and unsigned builds cannot use the privileged helper.
The helper exposes only a time-zone operation, validates the zone, and checks
the client signature and active console user. It does not accept shell commands.

For a signed Release build, pass `CODE_SIGN_STYLE=Manual`,
`DEVELOPMENT_TEAM=<team-id>`, and `CODE_SIGN_IDENTITY=<certificate-hash>` to
the Release build command. Keep the app at a stable path after helper approval.
To revoke helper approval, disable Date Day in macOS Login Items & Extensions.

Generate the Xcode project, run the tests, and build the Release app:

```sh
xcodegen generate
xcodebuild -project DateDay.xcodeproj -scheme DateDay \
  -destination 'platform=macOS' \
  -derivedDataPath .derived-data test
xcodebuild -project DateDay.xcodeproj -scheme DateDay \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .derived-data build
open .derived-data/Build/Products/Release/DateDay.app
```

Date Day is a menu-bar-only app, so it does not show an icon in the Dock. Click
the date in the menu bar to open its menu and settings.

## App icon assets

The source artwork is in `Artwork`. To regenerate all macOS app icon sizes,
run:

```sh
scripts/generate_app_icons.sh
```

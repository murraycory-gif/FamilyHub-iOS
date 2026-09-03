# TestFlight + first-run check

## On this Mac (owner iPad)

1. Xcode → FamilyHub target → **Signing & Capabilities**
2. Add **iCloud** → check **CloudKit**
3. Container: `iCloud.com.corymurray.FamilyHub` (create if Xcode offers)
4. Product → Archive → Distribute App → **TestFlight Internal**
5. On the iPad after install: Settings → Invite → **Publish this HUB now**
6. Share the 6-character code

## Wife / second device

1. Accept TestFlight invite, install HUB
2. First screen: **Join a family HUB**
3. Enter the code → pick her profile → Open HUB
4. Both devices must be signed into iCloud

## Walk the app like a new download (your iPad)

Settings → Invite → **Start as a new download**

Then:

1. Create this HUB
2. Your name
3. Household name
4. Add people
5. City / weather
6. Calendars
7. Bills calendar
8. Pings
9. Copy the join code, Publish this HUB now

iPhone: same TestFlight build. Hub stacks agenda then widgets in portrait. Family strip shows 2 cards.

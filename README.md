# FamilyHub iOS

Native **SwiftUI** family hub for **iPad first**, iPhone next.

Calendars (family + per person), upcoming, reminders, to-dos, and a chore board
your sons can check off for allowance.

Same workflow as EnviroMap: Xcode project in git, Fastlane for Mac builds.

## Open in Xcode

```bash
cd ~/Developer
git clone https://github.com/murraycory-gif/FamilyHub-iOS.git
cd FamilyHub-iOS
open FamilyHub.xcodeproj
```

1. Select the **FamilyHub** scheme and an **iPad** simulator (or your iPad).
2. Signing & Capabilities → choose your Team (automatic signing).
3. Run.

Pull later updates:

```bash
cd ~/Developer/FamilyHub-iOS
git pull
```

## What’s in this foundation

| Area | Status |
|------|--------|
| Household + members | Working (edit names, roles, colors) |
| Family / person calendar | Working month view + add event |
| Upcoming | Working (events + due chores + reminders) |
| Reminders | Working check-off |
| To-dos | Working check-off |
| Chores + rewards | Assign → kid checks off → parent approves $ |
| Allowance ledger | Working |
| iCloud / Family Sharing | Later |
| EventKit / Apple Calendar sync | Later |
| Push notifications | Later |

Data lives on-device as JSON in Application Support (`HubStore`), same idea as
EnviroMap’s `SessionStore`. Easy to swap iCloud later.

## Automated testing (Fastlane)

See [FASTLANE.md](FASTLANE.md).

```bash
bundle install
bundle exec fastlane qa
```

## Open items

See [OPEN_ITEMS.md](OPEN_ITEMS.md).

# HUB iOS

Native **SwiftUI** family hub for **iPad first**, iPhone next.

Calendars, weather, shopping, meals, chores, reminders, and to-dos.

Same Mac terminal workflow as **Fulfillment Heartbeat**.

## Daily commands (Mac Terminal)

First time only:

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/murraycory-gif/FamilyHub-iOS.git
cd FamilyHub-iOS
chmod +x update.sh install-ipad.sh repair.sh
```

Then, every time you sit down:

**Pull latest + open Xcode**

```bash
cd ~/Developer/FamilyHub-iOS && ./update.sh
```

**Build and put it on the iPad** (unlock the iPad, plug it in, Trust)

```bash
cd ~/Developer/FamilyHub-iOS && ./install-ipad.sh
```

If the cable dropped after a successful build:

```bash
cd ~/Developer/FamilyHub-iOS && SKIP_BUILD=1 ./install-ipad.sh
```

**Xcode project is broken / pull failed**

```bash
cd ~/Developer/FamilyHub-iOS && ./repair.sh
```

That resets to GitHub `main`, keeps your Apple team, and installs on the iPad.

Quit Xcode (Cmd+Q) before `./update.sh` or `./repair.sh`.

## Signing (one time)

1. `./update.sh` opens Xcode.
2. Select the **FamilyHub** scheme and your iPad.
3. Signing & Capabilities → Team (automatic signing).
4. After that, `./install-ipad.sh` uses that team.

## Automated testing (Fastlane)

See [FASTLANE.md](FASTLANE.md).

```bash
bundle install
bundle exec fastlane qa
```

## Open items

See [OPEN_ITEMS.md](OPEN_ITEMS.md).

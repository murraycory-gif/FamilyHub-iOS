# FamilyHub — Fastlane

Automates **build** and **unit tests** on your Mac. Same pattern as EnviroMap.

## One-time setup

```bash
cd ~/Developer/FamilyHub-iOS
git pull
bundle install
```

If `bundle` is missing:

```bash
sudo gem install bundler
bundle install
```

## Lanes

| Command | What it does |
|---------|----------------|
| `bundle exec fastlane build` | Compile app for iOS Simulator |
| `bundle exec fastlane build_clean` | Clean + compile |
| `bundle exec fastlane tests` | Run `FamilyHubTests` on Simulator |
| `bundle exec fastlane qa` | Build + tests + list open High items |
| `bundle exec fastlane open_items` | Print High+Open rows from `OPEN_ITEMS.md` |
| `bundle exec fastlane device_build` | Build for physical iPad/iPhone (signing required) |
| `bundle exec fastlane sims` | List simulators |

Prefer an iPad simulator:

```bash
export SCAN_DEVICE="iPad (10th generation)"
bundle exec fastlane tests
```

## What Fastlane covers vs device QA

| Automated (Fastlane / Simulator) | Manual (Cory’s iPad) |
|----------------------------------|----------------------|
| Compiles without errors | Sidebar + landscape on iPad |
| Chore complete → approve credits $ | Kid check-off feel |
| Calendar filter (family vs person) | Add/edit a real family event |
| Open-items file present | Rename sons in Family |

## Reports

After `tests` or `qa`:

- `build/test_output/report.html`
- `build/test_output/report.junit`

## Troubleshooting

- **No scheme FamilyHub** → open `FamilyHub.xcodeproj` once in Xcode, then re-run
- **Signing errors on device_build** → set Team in Xcode Signing & Capabilities
- **scan device not found** → `fastlane sims` and set `SCAN_DEVICE`

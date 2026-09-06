#!/bin/sh
# One command: pull latest HUB and put it on the iPad.
set -eu
cd "$(dirname "$0")"

PBX="FamilyHub.xcodeproj/project.pbxproj"
TEAM=""
if [ -f "$PBX" ]; then
  TEAM=$(awk -F'= |;' '/DEVELOPMENT_TEAM/ { gsub(/^[ \t"]+|[ \t"]+$/, "", $2); if ($2 != "" && $2 != "\"\"" ) { print $2; exit } }' "$PBX")
fi

git fetch origin
git rebase --abort >/dev/null 2>&1 || true
git merge --abort >/dev/null 2>&1 || true
git cherry-pick --abort >/dev/null 2>&1 || true

if git diff --name-only --diff-filter=U | grep -q . || grep -q '<<<<<<<' "$PBX" 2>/dev/null; then
  echo "Local project file was stuck. Resetting to the latest app..."
  git reset --hard origin/main
elif ! git pull --rebase --autostash origin main; then
  echo "Pull failed. Resetting to the latest app and keeping your signing..."
  git reset --hard origin/main
fi

if [ -z "${TEAM:-}" ] && [ -f .signing-team ]; then
  TEAM=$(tr -d '[:space:]' < .signing-team)
fi

if [ -z "${TEAM:-}" ]; then
  TEAM=$(grep -h "DEVELOPMENT_TEAM" FamilyHub.xcodeproj/project.pbxproj 2>/dev/null | head -1 | sed -E 's/.*DEVELOPMENT_TEAM = ([^;]+);.*/\1/' | tr -d ' "')
fi

if [ -n "${TEAM:-}" ]; then
  printf '%s\n' "$TEAM" > .signing-team
  python3 - "$PBX" "$TEAM" <<'PY'
import pathlib, sys, re
path, team = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
text = re.sub(r'DEVELOPMENT_TEAM = [^;]+;', f'DEVELOPMENT_TEAM = {team};', text)
text = re.sub(
    r'CODE_SIGN_STYLE = Automatic;(?!\n[ \t]*DEVELOPMENT_TEAM)',
    f'CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = {team};',
    text,
)
path.write_text(text)
print(f"Kept your Apple team: {team}")
PY
else
  echo "No Apple team saved yet. Open the project once in Xcode, pick your team on FamilyHub and FamilyHubWidgets, then rerun ./go.sh"
fi

exec ./install-ipad.sh

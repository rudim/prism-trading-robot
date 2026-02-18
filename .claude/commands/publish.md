Publish the Prism EA source to the MetaTrader 5 experts folder.

**Source:** `source/` in the repository root
**Destination:** `/Users/rudimostert/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Prism`
**What to copy:** `source/prism.mq5` (and any other `.mq5` files in `source/`) plus the entire `source/Includes/` folder.

## Steps to execute

Run each of the following steps using the Bash tool. Show the user what happened at each step.

### Step 1 — Verify source exists

Confirm `source/prism.mq5` and `source/Includes/` are present in the working directory. Abort with a clear message if either is missing.

### Step 2 — Determine archive version number and archive `latest`

```bash
DEST="/Users/rudimostert/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/Prism"

# Find the highest existing version folder (e.g. 0.1, 0.5, 1.2)
highest=$(ls "$DEST" | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -1)

if [ -z "$highest" ]; then
  new_version="0.1"
else
  new_version=$(python3 -c "v=float('$highest'); print(f'{v+0.1:.1f}')")
fi

echo "Highest existing version: ${highest:-none}"
echo "Next archive version: $new_version"

# Archive latest only if it contains files
if [ -d "$DEST/latest" ] && [ "$(ls -A "$DEST/latest")" ]; then
  mv "$DEST/latest" "$DEST/$new_version"
  # Rename the .mq5 file to include the version tag
  for f in "$DEST/$new_version"/*.mq5; do
    base=$(basename "$f" .mq5)
    mv "$f" "$DEST/$new_version/${base}-${new_version}.mq5"
  done
  echo "Archived: latest → $new_version"
else
  # Empty or absent — remove cleanly without consuming a version number
  rm -rf "$DEST/latest"
  echo "Previous latest was empty — no version archived."
fi
```

### Step 3 — Copy source to new `latest`

```bash
mkdir -p "$DEST/latest/Includes"

# Copy all .mq5 files from source/ and rename to include -latest suffix
for f in source/*.mq5; do
  base=$(basename "$f" .mq5)
  cp "$f" "$DEST/latest/${base}-latest.mq5"
done

# Copy all .mqh include files
cp source/Includes/*.mqh "$DEST/latest/Includes/"
```

### Step 4 — Confirm result

```bash
echo ""
echo "=== Prism folder ==="
ls "$DEST"
echo ""
echo "=== latest/ ==="
ls "$DEST/latest/"
echo ""
echo "=== latest/Includes/ ==="
ls "$DEST/latest/Includes/"
```

Report a summary to the user:
- Whether a previous `latest` was archived (and which version it became), or skipped because it was empty
- The list of files now in `latest/` and `latest/Includes/`
- Reminder to recompile `prism-latest.mq5` in MetaEditor (F7)

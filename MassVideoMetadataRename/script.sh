#!/bin/bash

# --- Detect OS for date compatibility ---
IS_MAC=false
if [[ "$OSTYPE" == "darwin"* ]]; then
  IS_MAC=true
fi

# --- Script location becomes working root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
X_DIR_NAME="$(basename "$ROOT")"
X="${X_DIR_NAME#Pool}"

START_DATETIME="$1"  # Format: "YYYY-MM-DD HH:MM"

if [[ -z "$START_DATETIME" ]]; then
  echo "Usage: ./fix_camera_videos.sh 'YYYY-MM-DD HH:MM'"
  exit 1
fi

# --- Convert start datetime to timestamp ---
if $IS_MAC; then
  START_TS=$(date -j -f "%Y-%m-%d %H:%M" "$START_DATETIME" "+%s")
else
  START_TS=$(date -d "$START_DATETIME" "+%s")
fi

# --- Initialize ---
FIRST_FAKE_TS=""
TARGET_DIR=""
echo "🚀 Starting timestamp correction in: $ROOT"
echo "📅 Corrected base datetime: $START_DATETIME ($START_TS)"

# --- Process each .mp4 file ---
find "$ROOT" -type f -name "*.mp4" | grep -v "_CAM" | sort | while read -r filepath; do
  # Extract date, hour, and minute from original folder structure (and optional -new suffix)
  if [[ "$filepath" =~ /([0-9]{8})/([0-9]{1,2})/([0-9]{1,2})(-new)?\.mp4$ ]]; then
    fake_date="${BASH_REMATCH[1]}"
    hour="${BASH_REMATCH[2]}"
    minute="${BASH_REMATCH[3]}"
    is_new="${BASH_REMATCH[4]}"

    # Extract camera folder (W) from full path
    W_DIR_NAME=$(basename $(dirname $(dirname $(dirname "$filepath"))))
    W="$W_DIR_NAME"

    # Convert fake timestamp to UNIX time
    if $IS_MAC; then
      FAKE_TS=$(date -j -f "%Y%m%d %H %M" "$fake_date $hour $minute" "+%s")
    else
      FAKE_TS=$(date -d "$fake_date $hour:$minute" "+%s")
    fi

    # If file is marked as -new, add 1 day (86400 seconds)
    if [[ "$is_new" == "-new" ]]; then
      FAKE_TS=$((FAKE_TS + 86400))
    fi

    # Record first file's fake timestamp
    if [[ -z "$FIRST_FAKE_TS" ]]; then
      FIRST_FAKE_TS=$FAKE_TS
    fi

    # Calculate delta and real timestamp
    DELTA=$((FAKE_TS - FIRST_FAKE_TS))
    ACTUAL_TS=$((START_TS + DELTA))

    # Format new names and metadata timestamp
    if $IS_MAC; then
      NEW_DATE=$(date -r "$ACTUAL_TS" "+%Y%m%d")
      NEW_TIME=$(date -r "$ACTUAL_TS" "+%H%M")
      FF_DATE=$(date -u -r "$ACTUAL_TS" "+%Y-%m-%dT%H:%M:%S")
    else
      NEW_DATE=$(date -d "@$ACTUAL_TS" "+%Y%m%d")
      NEW_TIME=$(date -d "@$ACTUAL_TS" "+%H%M")
      FF_DATE=$(date -u -d "@$ACTUAL_TS" "+%Y-%m-%dT%H:%M:%S")
    fi

    # Prepare new paths
    TARGET_DIR="$ROOT/${NEW_DATE}_CAM${W}"
    mkdir -p "$TARGET_DIR"
    NEW_FILENAME="${X}_${NEW_DATE}_${NEW_TIME}.mp4"
    NEW_FILE="$TARGET_DIR/$NEW_FILENAME"
    TMP_FILE="${NEW_FILE%.mp4}_tmp.mp4"

    # Move and update metadata
    mv "$filepath" "$NEW_FILE"
    ffmpeg -i "$NEW_FILE" -metadata creation_time="$FF_DATE" -codec copy "$TMP_FILE" -y -loglevel error
    mv "$TMP_FILE" "$NEW_FILE"

    # Set file system timestamps
    if $IS_MAC; then
      touch -t "$(date -r "$ACTUAL_TS" "+%Y%m%d%H%M.%S")" "$NEW_FILE"
    else
      touch -d "@$ACTUAL_TS" "$NEW_FILE"
    fi

    echo "✅ $filepath → $NEW_FILE @ $FF_DATE"
  fi
done

# --- Cleanup: delete old empty folders ---

find "$ROOT" -name ".DS_Store" -delete
find "$ROOT" -name ".start_time" -delete

find "$ROOT" -type d -depth | while read -r dir; do
  # Skip new target dir and root
  if [[ "$dir" != "$TARGET_DIR" && "$dir" != "$ROOT" ]]; then
    if [ -z "$(ls -A "$dir")" ]; then
      rm -rf "$dir" && echo "🧹 Removed directory: $dir" && echo "🧹 Removed empty directory: $dir"
    fi
  fi
done

echo "🎉 All files processed!"

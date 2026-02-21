#!/bin/bash
# hvc1fix.sh - Fixes HEVC codec tag from hev1 → hvc1 for WebOS/Chromium compatibility
# Usage: ./hvc1fix.sh [DIRECTORY]
#        Default: current directory
#        Supports: .mp4, .m4v

INPUT_DIR="${1:-.}"
FIXED=0
SKIPPED=0
ERRORS=0

for f in "$INPUT_DIR"/**/*.mp4 "$INPUT_DIR"/**/*.m4v \
          "$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.m4v; do
    [ -f "$f" ] || continue

    # Codec-Tag des ersten Video-Streams prüfen
    tag=$(ffprobe -v error \
        -select_streams v:0 \
        -show_entries stream=codec_tag_string \
        -of csv=p=0 "$f" 2>/dev/null)

    if [ "$tag" != "hev1" ]; then
        echo "  ✓ Skip (Tag ist bereits '${tag}'): $(basename "$f")"
        ((SKIPPED++))
        continue
    fi

    echo "==> Fixing: $f"
    echo "    → Tag: hev1 → hvc1"

    tmp="${f%.mp*}_hvc1fix.mp4"

    ffmpeg -v warning \
        -i "$f" \
        -c copy \
        -tag:v:0 hvc1 \
        -map 0 \
        "$tmp" -y

    if [ $? -eq 0 ]; then
        mv "$tmp" "$f"
        echo "    ✓ Fertig: $(basename "$f")"
        ((FIXED++))
    else
        echo "    ✗ Fehler bei: $(basename "$f")"
        rm -f "$tmp"
        ((ERRORS++))
    fi

    echo ""
done

echo "================================================"
echo "  Fertig: ${FIXED} gefixed | ${SKIPPED} übersprungen | ${ERRORS} Fehler"
echo "================================================"

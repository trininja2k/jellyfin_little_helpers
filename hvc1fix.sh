#!/bin/bash
# hvc1fix.sh - Fixes HEVC codec tag from hev1 → hvc1 for WebOS/Chromium compatibility
# Usage: ./hvc1fix.sh [DIRECTORY]
#        Default: current directory
#        Supports: .mp4, .m4v

INPUT_DIR="${1:-.}"
FIXED=0
SKIPPED=0
ERRORS=0

while IFS= read -r -d '' f; do
    # _hvc1fix.mp4 Temp-Dateien überspringen
    [[ "$f" == *_hvc1fix.mp4 ]] && continue

    tag=$(ffprobe -v error \
        -select_streams v:0 \
        -show_entries stream=codec_tag_string \
        -of csv=p=0 "$f" 2>/dev/null | tr -d '[:space:]')

    codec=$(ffprobe -v error \
        -select_streams v:0 \
        -show_entries stream=codec_name \
        -of csv=p=0 "$f" 2>/dev/null | tr -d '[:space:]')

    needs_fix=false
    if [ "$tag" = "hev1" ] || [ "$tag" = "0x31766568" ]; then
        needs_fix=true
    elif [ "$codec" = "hevc" ] && [ "$tag" != "hvc1" ]; then
        needs_fix=true
    fi

    if ! $needs_fix; then
        echo "  ✓ Skip (codec='${codec}' tag='${tag}'): $(basename "$f")"
        ((SKIPPED++))
        continue
    fi

    echo "==> Fixing: $f"
    echo "    → codec='${codec}' tag='${tag}' → hvc1"

    tmp="${f%.*}_hvc1fix.mp4"

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
done < <(find "$INPUT_DIR" \( -iname "*.mp4" -o -iname "*.m4v" \) -type f -print0)

echo "================================================"
echo "  Fertig: ${FIXED} gefixed | ${SKIPPED} übersprungen | ${ERRORS} Fehler"
echo "================================================"

#!/bin/bash
# hvc1fix.sh - Fixes HEVC codec tag from hev1 → hvc1 for WebOS/Chromium compatibility
# Usage: ./hvc1fix.sh [DIRECTORY]
#        Default: current directory recursive
#        Supports: .mp4, .m4v

INPUT_DIR="${1:-.}"
FIXED=0
SKIPPED=0
ERRORS=0
RETRY_COUNT=3
RETRY_DELAY=5

ffprobe_get() {
    local field="$1"
    local file="$2"
    local result
    result=$(ffprobe -v error \
        -select_streams v:0 \
        -show_entries "stream=${field}" \
        -of csv=p=0 \
        -- "$file" 2>/dev/null | tr -d '[:space:]')
    echo "$result"
}

while IFS= read -r -d '' f; do
    [[ "$f" == *_hvc1fix.mp4 ]] && continue

    codec=""
    for ((i=1; i<=RETRY_COUNT; i++)); do
        codec=$(ffprobe_get codec_name "$f")
        [ -n "$codec" ] && break
        echo "    x > ffprobe Versuch ${i}/${RETRY_COUNT} fehlgeschlagen (leer): $(basename "$f")" >&2
        sleep "$RETRY_DELAY"
    done

    if [ -z "$codec" ]; then
        echo "    * > Übersprungen (ffprobe nach ${RETRY_COUNT} Versuchen fehlgeschlagen): $(basename "$f")"
        ((ERRORS++))
        echo ""
        continue
    fi

    tag=$(ffprobe_get codec_tag_string "$f")

    needs_fix=false
    if [ "$tag" = "hev1" ] || [ "$tag" = "0x31766568" ]; then
        needs_fix=true
    elif [ "$codec" = "hevc" ] && [ "$tag" != "hvc1" ]; then
        needs_fix=true
    fi

    if ! $needs_fix; then
        echo "   - > Skip (codec='${codec}' tag='${tag}'): $(basename "$f")"
        ((SKIPPED++))
        continue
    fi

    echo "==> Fixing: $f"
    echo "    - > codec='${codec}' tag='${tag}' → hvc1"

    tmp="${f%.*}_hvc1fix.mp4"

    ffmpeg -v warning \
        -i "$f" \
        -c copy \
        -tag:v:0 hvc1 \
        -map 0 \
        -- "$tmp" -y

    if [ $? -eq 0 ]; then
        mv -- "$tmp" "$f"
        echo "    - > Fertig: $(basename "$f")"
        ((FIXED++))
    else
        echo "    x > Fehler bei: $(basename "$f")"
        rm -f -- "$tmp"
        ((ERRORS++))
    fi

    echo ""
done < <(find "$INPUT_DIR" \( -iname "*.mp4" -o -iname "*.m4v" \) -type f -print0)

echo "================================================"
echo "  Fertig: ${FIXED} gefixed | ${SKIPPED} übersprungen | ${ERRORS} Fehler"
echo "================================================"

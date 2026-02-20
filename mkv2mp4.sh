#!/bin/bash
# mkv2mp4.sh - MKV → MP4 Remux für WebOS (HEVC-kompatibel)
# - Text-Subs (ASS/SRT/WebVTT) → mov_text
# - Bild-Subs (PGS/VobSub) → externe Datei extrahieren
# - Unbekannte Subs → weglassen

INPUT_DIR="${1:-.}"

for f in "$INPUT_DIR"/*.mkv; do
    [ -f "$f" ] || continue
    out="${f%.mkv}.mp4"

    echo "==> Processing: $f"

    # Alle Subtitle-Streams auslesen
    mapfile -t sub_codecs < <(ffprobe -v error \
        -select_streams s \
        -show_entries stream=index,codec_name \
        -of csv=p=0 "$f")

    SUB_MAP_ARGS=()
    SUB_CODEC_ARGS=()
    has_text_sub=false
    has_bitmap_sub=false

    for entry in "${sub_codecs[@]}"; do
        stream_index="${entry%%,*}"
        codec="${entry##*,}"

        case "$codec" in
            ass|ssa|subrip|srt|webvtt|mov_text)
                # Text-basiert → mov_text inline
                SUB_MAP_ARGS+=(-map "0:${stream_index}")
                has_text_sub=true
                ;;
            hdmv_pgs_subtitle|dvd_subtitle|dvb_subtitle)
                # Bild-basiert → extern extrahieren
                has_bitmap_sub=true
                ext="sup"
                [ "$codec" = "dvd_subtitle" ] && ext="sub"
                out_sub="${f%.mkv}.stream${stream_index}.${ext}"

                echo "    → Extrahiere Bild-Sub (${codec}) → $(basename "$out_sub")"
                ffmpeg -v warning -i "$f" \
                    -map "0:${stream_index}" \
                    -c:s copy \
                    "$out_sub" -y
                ;;
            *)
                echo "    ⚠ Unbekannter Sub-Codec '${codec}' (Stream ${stream_index}) → wird übersprungen"
                ;;
        esac
    done

    # Codec-Argument nur setzen wenn text-subs vorhanden
    $has_text_sub && SUB_CODEC_ARGS=(-c:s mov_text)

    echo "    → Remux Video+Audio$(${has_text_sub} && echo '+TextSubs' || echo '')"

    ffmpeg -v warning -i "$f" \
        -map 0:v \
        -map 0:a \
        "${SUB_MAP_ARGS[@]}" \
        -c:v copy \
        -c:a copy \
        "${SUB_CODEC_ARGS[@]}" \
        -map_chapters 0 \
        -movflags +faststart \
        "$out" -y

    if [ $? -eq 0 ]; then
        echo "    ✓ Fertig: $(basename "$out")"
    else
        echo "    ✗ Fehler bei: $(basename "$f")"
        rm -f "$out"
    fi

    echo ""
done

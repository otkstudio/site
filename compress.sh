#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  compress.sh — Portfolio media pipeline                                      ║
# ║                                                                              ║
# ║  Usage:                                                                      ║
# ║    ./compress.sh <slug>                     Process all media for <slug>     ║
# ║    ./compress.sh <slug> --desktop-only      Desktop images + video only      ║
# ║    ./compress.sh <slug> --mobile-only       Mobile images + video only       ║
# ║    ./compress.sh <slug> --images-only       Still images only                ║
# ║    ./compress.sh <slug> --video-only        Video + posters only             ║
# ║    ./compress.sh <slug> --posters-only      Poster extraction only           ║
# ║    ./compress.sh <slug> --thumbnails-only   Thumbnails only                  ║
# ║    ./compress.sh <slug> --force             Re-encode existing output files  ║
# ║                                                                              ║
# ║  Source files expected in:                                                   ║
# ║    src/<slug>/desktop.<ext>   5120×2880 still image                         ║
# ║    src/<slug>/desktop.mov     3840×2160 ProRes 4444 video  → desktop/       ║
# ║    src/<slug>/desktop.mp4     accepted in place of .mov                     ║
# ║    src/<slug>/mobile.<ext>    2160×2700 still image                         ║
# ║    src/<slug>/mobile.mov      2160×2700 ProRes 4444 video  → mobile/        ║
# ║    src/<slug>/mobile.mp4      accepted in place of .mov                     ║
# ║    src/<slug>/device.mov      screen recording at native res → device/      ║
# ║    src/<slug>/device.mp4      accepted in place of .mov                     ║
# ║                                                                              ║
# ║  All quality settings live in compress.config.sh                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/compress.config.sh"

# ── Sizing ladders ──────────────────────────────────────────────────────────────

# Desktop 16:9 — widths only; heights derived from 16:9 ratio
# Each width = macOS "Looks Like" logical width × 2 (Retina DPR).
# "Looks Like" is what macOS scales the native panel down to — what CSS/JS sees as window.innerWidth.
# The browser requests this physical size from srcset.
#   5120 — Apple Studio Display      (2560 "Looks Like" × 2×)
#   3456 — MacBook Pro 16"           (1728 "Looks Like" × 2×)
#   3420 — MacBook Air 15" M2/M3     (1710 "Looks Like" × 2×)
#   3024 — MacBook Pro 14"           (1512 "Looks Like" × 2×)
#   2940 — MacBook Air 13" M2/M3     (1470 "Looks Like" × 2×)
#   2560 — MacBook Air 13" M1 / MBP 13"  (1280 "Looks Like" × 2×)
#   1920 — base fallback
DESKTOP_IMG_WIDTHS=(5120 3456 3420 3024 2940 2560 1920)
DESKTOP_VID_WIDTHS=(3840 2560 1920)

# Mobile 4:5 — widths × heights at 5/4 ratio:
#   2160 — source top; 1080px logical × 2× (tablets, large phones)
#   1800 — 900px logical × 2× (tablet breakpoint)
#   1290 — iPhone Plus/Max (430px logical × 3×)
#   1080 — floor
MOBILE_WIDTHS=(2160 1800 1290 1080)
MOBILE_HEIGHTS=(2700 2250 1613 1350)

# ── Flags ───────────────────────────────────────────────────────────────────────

SLUG=""
DO_DESKTOP=true
DO_MOBILE=true
DO_IMAGES=true
DO_VIDEO=true
DO_POSTERS=true
DO_THUMBNAILS=true
FORCE=false

# ── Parse arguments ─────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  echo "Usage: ./compress.sh <slug> [--desktop-only] [--mobile-only] [--images-only] [--video-only] [--posters-only] [--thumbnails-only] [--force]"
  exit 1
fi

SLUG="$1"
shift

for arg in "$@"; do
  case "$arg" in
    --desktop-only)    DO_MOBILE=false ;;
    --mobile-only)     DO_DESKTOP=false ;;
    --images-only)     DO_VIDEO=false; DO_POSTERS=false ;;
    --video-only)      DO_IMAGES=false ;;
    --posters-only)    DO_IMAGES=false; DO_VIDEO=false ;;
    --thumbnails-only) DO_IMAGES=false; DO_VIDEO=false; DO_POSTERS=false ;;
    --force)           FORCE=true ;;
    *)
      echo "Unknown flag: $arg"
      exit 1
      ;;
  esac
done

# ── Paths ───────────────────────────────────────────────────────────────────────

CONTENT_DIR="$SCRIPT_DIR/content"
SOURCES_DIR="$SCRIPT_DIR/src/$SLUG"
OUT_DIR="$CONTENT_DIR/$SLUG"

# ── Colours for output ──────────────────────────────────────────────────────────

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# ── Helpers ─────────────────────────────────────────────────────────────────────

log_section() { echo -e "\n${BOLD}${CYAN}▶  $1${RESET}"; }
log_item()    { echo -e "   ${DIM}→${RESET}  $1"; }
log_ok()      { echo -e "   ${GREEN}✓${RESET}  $1"; }
log_skip()    { echo -e "   ${DIM}–  $1 (exists, skipping)${RESET}"; }
log_warn()    { echo -e "   ${YELLOW}⚠  $1${RESET}"; }
log_error()   { echo -e "   ${RED}✗  $1${RESET}"; }

# Find a source file regardless of image extension (.png .jpg .tiff .psd etc.)
find_source_image() {
  local dir="$1" base="$2"
  for ext in svg SVG png PNG jpg JPG jpeg JPEG tiff TIFF tif TIF heic HEIC; do
    local candidate="$dir/$base.$ext"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# Find a poster source file (poster.<ext>) regardless of image extension
find_source_poster() {
  local dir="$1"
  for ext in png PNG jpg JPG jpeg JPEG tiff TIFF tif TIF heic HEIC; do
    local candidate="$dir/poster.$ext"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# Find a thumbnail override (thumbnail.<ext>) regardless of image extension
find_source_thumbnail() {
  local dir="$1"
  for ext in png PNG jpg JPG jpeg JPEG tiff TIFF tif TIF heic HEIC; do
    local candidate="$dir/thumbnail.$ext"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# Return 0 if output should be written (missing or --force)
should_encode() {
  local out="$1"
  if [[ "$FORCE" == true ]] || [[ ! -f "$out" ]]; then
    return 0
  fi
  return 1
}

# ── Dependency check ────────────────────────────────────────────────────────────

check_deps() {
  local missing=()
  command -v ffmpeg  &>/dev/null || missing+=("ffmpeg")
  command -v magick  &>/dev/null || missing+=("magick (ImageMagick 7)")
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing dependencies: ${missing[*]}"
    echo "  Install with: brew install ffmpeg imagemagick"
    exit 1
  fi
}

# ── Image encoding ──────────────────────────────────────────────────────────────

# encode_image <input> <width> <height> <output>
encode_image() {
  local input="$1" w="$2" h="$3" output="$4"

  if ! should_encode "$output"; then
    log_skip "$(basename "$output")"
    return
  fi

  ensure_dir "$output"
  log_item "$(basename "$output")  (${w}×${h})"

  local extra_flags=()

  # Lossless vs quality
  if [[ "$IMG_LOSSLESS" == true ]]; then
    case "$IMG_FORMAT" in
      avif) extra_flags+=(-define "avif:lossless=true") ;;
      webp) extra_flags+=(-define "webp:lossless=true") ;;
      png)  : ;;  # PNG is always lossless
    esac
  else
    extra_flags+=(-quality "$IMG_QUALITY")
  fi

  # AVIF encoding speed
  if [[ "$IMG_FORMAT" == "avif" ]]; then
    extra_flags+=(-define "avif:speed=${IMG_AVIF_SPEED}")
  fi

  # Strip metadata
  if [[ "$IMG_STRIP_METADATA" == true ]]; then
    extra_flags+=(-strip)
  fi

  magick "$input" \
    -filter "$IMG_FILTER" \
    -resize "${w}x${h}!" \
    "${extra_flags[@]}" \
    "$output"

  log_ok "$(basename "$output")  ($(du -sh "$output" | cut -f1))"
}

# ── Thumbnail encoding ──────────────────────────────────────────────────────────

# encode_thumbnail <input> <output>
# Always outputs WebP at THUMB_WIDTH × (THUMB_WIDTH*9/16), ignoring IMG_FORMAT.
encode_thumbnail() {
  local input="$1" output="$2"
  local w="$THUMB_WIDTH"
  local h=$(( w * 9 / 16 ))

  if ! should_encode "$output"; then
    log_skip "$(basename "$output")"
    return
  fi

  ensure_dir "$output"
  log_item "$(basename "$output")  (${w}×${h}  thumbnail)"

  local extra_flags=()
  if [[ "$THUMB_LOSSLESS" == true ]]; then
    extra_flags+=(-define "webp:lossless=true")
  else
    extra_flags+=(-quality "$THUMB_QUALITY")
  fi

  if [[ "$IMG_STRIP_METADATA" == true ]]; then
    extra_flags+=(-strip)
  fi

  magick "$input" \
    -filter "$IMG_FILTER" \
    -resize "${w}x${h}!" \
    "${extra_flags[@]}" \
    "webp:${output}"

  log_ok "$(basename "$output")  ($(du -sh "$output" | cut -f1))"
}

# ── Poster extraction ────────────────────────────────────────────────────────────

# extract_poster <input_video> <width> <height> <output>
extract_poster() {
  local input="$1" w="$2" h="$3" output="$4"

  if ! should_encode "$output"; then
    log_skip "$(basename "$output")"
    return
  fi

  ensure_dir "$output"
  log_item "poster $(basename "$output")  (${w}×${h})"

  # Extract the target frame to a temp PNG then convert via ImageMagick
  # (gives us full control over output format + quality flags)
  local tmp_frame
  tmp_frame="$(mktemp /tmp/compress_poster_XXXXXX).png"

  ffmpeg -loglevel error \
    -i "$input" \
    -vf "select=eq(n\\,${POSTER_FRAME}),scale=${w}:${h}:flags=lanczos" \
    -frames:v 1 \
    -update 1 \
    -y "$tmp_frame"

  local extra_flags=()

  if [[ "$POSTER_LOSSLESS" == true ]]; then
    case "$POSTER_FORMAT" in
      avif) extra_flags+=(-define "avif:lossless=true") ;;
      webp) extra_flags+=(-define "webp:lossless=true") ;;
    esac
  else
    extra_flags+=(-quality "$POSTER_QUALITY")
  fi

  if [[ "$IMG_STRIP_METADATA" == true ]]; then
    extra_flags+=(-strip)
  fi

  magick "$tmp_frame" "${extra_flags[@]}" "$output"
  rm -f "$tmp_frame"

  log_ok "$(basename "$output")  ($(du -sh "$output" | cut -f1))"
}

# ── Video encoding ──────────────────────────────────────────────────────────────

# build_vf_filter <width> <height>  → prints the -vf value
build_vf_filter() {
  local w="$1" h="$2"
  local vf="scale=${w}:${h}"
  if [[ "$VID_FPS" != "source" ]]; then
    vf="${vf},fps=${VID_FPS}"
  fi
  echo "$vf"
}

# encode_video_h264 <input> <width> <height> <output>
encode_video_h264() {
  local input="$1" w="$2" h="$3" output="$4"

  if ! should_encode "$output"; then log_skip "$(basename "$output")"; return; fi
  ensure_dir "$output"
  log_item "$(basename "$output")  (${w}×${h}  H.264)"

  local crf_flag=()
  if [[ "$VID_LOSSLESS" == true ]]; then
    crf_flag=(-crf 0)
  else
    crf_flag=(-crf "$VID_CRF_H264")
  fi

  local audio_flag=()
  [[ "$VID_NO_AUDIO" == true ]] && audio_flag=(-an)

  local faststart_flag=()
  [[ "$VID_FASTSTART" == true ]] && faststart_flag=(-movflags faststart)

  ffmpeg -loglevel error -stats \
    -i "$input" \
    -c:v libx264 \
    "${crf_flag[@]}" \
    -preset "$VID_PRESET" \
    -vf "$(build_vf_filter "$w" "$h")" \
    "${faststart_flag[@]}" \
    "${audio_flag[@]}" \
    -y "$output"

  log_ok "$(basename "$output")  ($(du -sh "$output" | cut -f1))"
}

# encode_video_h265 <input> <width> <height> <output>
encode_video_h265() {
  local input="$1" w="$2" h="$3" output="$4"

  if ! should_encode "$output"; then log_skip "$(basename "$output")"; return; fi
  ensure_dir "$output"
  log_item "$(basename "$output")  (${w}×${h}  H.265)"

  local crf_flag=()
  if [[ "$VID_LOSSLESS" == true ]]; then
    crf_flag=(-crf 0)
  else
    crf_flag=(-crf "$VID_CRF_H265")
  fi

  local audio_flag=()
  [[ "$VID_NO_AUDIO" == true ]] && audio_flag=(-an)

  local faststart_flag=()
  [[ "$VID_FASTSTART" == true ]] && faststart_flag=(-movflags faststart)

  ffmpeg -loglevel error -stats \
    -i "$input" \
    -c:v libx265 \
    "${crf_flag[@]}" \
    -preset "$VID_PRESET" \
    -tag:v hvc1 \
    -vf "$(build_vf_filter "$w" "$h")" \
    "${faststart_flag[@]}" \
    "${audio_flag[@]}" \
    -y "$output"

  log_ok "$(basename "$output")  ($(du -sh "$output" | cut -f1))"
}

# encode_video_vp9 <input> <width> <height> <output>
encode_video_vp9() {
  local input="$1" w="$2" h="$3" output="$4"

  if ! should_encode "$output"; then log_skip "$(basename "$output")"; return; fi
  ensure_dir "$output"
  log_item "$(basename "$output")  (${w}×${h}  VP9)"

  local quality_flags=()
  if [[ "$VID_LOSSLESS" == true ]]; then
    quality_flags=(-lossless 1)
  else
    quality_flags=(-crf "$VID_CRF_VP9" -b:v 0)
  fi

  local audio_flag=()
  [[ "$VID_NO_AUDIO" == true ]] && audio_flag=(-an)

  # VP9 deadline mapped from VID_PRESET
  local deadline="good"
  case "$VID_PRESET" in
    ultrafast|superfast|veryfast|faster|fast) deadline="good" ;;
    medium)   deadline="good" ;;
    slow|veryslow) deadline="best" ;;
  esac

  ffmpeg -loglevel error -stats \
    -i "$input" \
    -c:v libvpx-vp9 \
    "${quality_flags[@]}" \
    -deadline "$deadline" \
    -vf "$(build_vf_filter "$w" "$h")" \
    "${audio_flag[@]}" \
    -y "$output"

  log_ok "$(basename "$output")  ($(du -sh "$output" | cut -f1))"
}

# encode_video_av1 <input> <width> <height> <output>
encode_video_av1() {
  local input="$1" w="$2" h="$3" output="$4"

  if ! should_encode "$output"; then log_skip "$(basename "$output")"; return; fi
  ensure_dir "$output"
  log_item "$(basename "$output")  (${w}×${h}  AV1)"

  local crf_flag=()
  if [[ "$VID_LOSSLESS" == true ]]; then
    crf_flag=(-crf 0)
  else
    crf_flag=(-crf "$VID_CRF_AV1" -b:v 0)
  fi

  local audio_flag=()
  [[ "$VID_NO_AUDIO" == true ]] && audio_flag=(-an)

  local faststart_flag=()
  [[ "$VID_FASTSTART" == true ]] && faststart_flag=(-movflags faststart)

  # SVT-AV1 speed preset (0–13, inverse of "slow")
  local svt_preset=6
  case "$VID_PRESET" in
    veryslow) svt_preset=1 ;;
    slow)     svt_preset=3 ;;
    medium)   svt_preset=6 ;;
    fast)     svt_preset=9 ;;
    veryfast) svt_preset=12 ;;
  esac

  ffmpeg -loglevel error -stats \
    -i "$input" \
    -c:v libsvtav1 \
    "${crf_flag[@]}" \
    -preset "$svt_preset" \
    -vf "$(build_vf_filter "$w" "$h")" \
    "${faststart_flag[@]}" \
    "${audio_flag[@]}" \
    -y "$output"

  log_ok "$(basename "$output")  ($(du -sh "$output" | cut -f1))"
}

# Dispatch to codec-specific encoders based on VID_CODECS setting
encode_video_all_codecs() {
  local input="$1" w="$2" h="$3" out_dir="$4" slug="$5"

  for codec in $VID_CODECS; do
    case "$codec" in
      h264) encode_video_h264 "$input" "$w" "$h" "${out_dir}/${slug}-${w}w-h264.mp4" ;;
      h265) encode_video_h265 "$input" "$w" "$h" "${out_dir}/${slug}-${w}w-h265.mp4" ;;
      vp9)  encode_video_vp9  "$input" "$w" "$h" "${out_dir}/${slug}-${w}w.webm" ;;
      av1)  encode_video_av1  "$input" "$w" "$h" "${out_dir}/${slug}-${w}w-av1.mp4" ;;
      *)    log_warn "Unknown codec '$codec' in VID_CODECS — skipping" ;;
    esac
  done
}

# ── Directory scaffold ──────────────────────────────────────────────────────────

# Called lazily just before writing a file so empty folders are never created
ensure_dir() { mkdir -p "$(dirname "$1")"; }

# ── Desktop pipeline ────────────────────────────────────────────────────────────

process_desktop_images() {
  local src
  if ! src="$(find_source_image "$SOURCES_DIR" "desktop")"; then
    log_warn "No desktop source image found in $SOURCES_DIR — skipping desktop images"
    return
  fi
  log_section "Desktop images  ←  $(basename "$src")"

  if [[ "$src" == *.svg || "$src" == *.SVG ]]; then
    if [[ "$DO_IMAGES" == true ]]; then
      local dest="$OUT_DIR/desktop/${SLUG}.svg"
      ensure_dir "$dest"
      log_item "SVG source — copying as-is (no resize ladder)"
      cp "$src" "$dest"
      log_ok "${SLUG}.svg"
    fi
    if [[ "$DO_THUMBNAILS" == true ]]; then
      local thumb_src="${THUMB_SRC_OVERRIDE:-$src}"
      encode_thumbnail "$thumb_src" "$OUT_DIR/desktop/${SLUG}-thumb.webp"
    fi
    return
  fi

  if [[ "$DO_IMAGES" == true ]]; then
    for w in "${DESKTOP_IMG_WIDTHS[@]}"; do
      local h=$(( w * 9 / 16 ))
      encode_image "$src" "$w" "$h" \
        "$OUT_DIR/desktop/${SLUG}-${w}w.${IMG_FORMAT}"
    done
  fi

  if [[ "$DO_THUMBNAILS" == true ]]; then
    local thumb_src="${THUMB_SRC_OVERRIDE:-$src}"
    encode_thumbnail "$thumb_src" "$OUT_DIR/desktop/${SLUG}-thumb.webp"
  fi
}

process_desktop_video() {
  local src=""
  for ext in mov mp4 MP4 MOV; do
    if [[ -f "$SOURCES_DIR/desktop.$ext" ]]; then
      src="$SOURCES_DIR/desktop.$ext"
      break
    fi
  done
  if [[ -z "$src" ]]; then
    log_warn "No desktop source video found (expected desktop.mov or desktop.mp4) — skipping"
    return
  fi
  log_section "Desktop video  ←  $(basename "$src")"

  local poster_src
  poster_src="$(find_source_poster "$SOURCES_DIR")" || true

  local vid_widths=("${DESKTOP_VID_WIDTHS[@]}")

  for w in "${vid_widths[@]}"; do
    local h=$(( w * 9 / 16 ))

    if [[ "$DO_VIDEO" == true ]]; then
      encode_video_all_codecs "$src" "$w" "$h" "$OUT_DIR/desktop" "$SLUG"
    fi

    if [[ "$DO_POSTERS" == true ]]; then
      if [[ -n "$poster_src" ]]; then
        encode_image "$poster_src" "$w" "$h" \
          "$OUT_DIR/desktop/${SLUG}-${w}w-poster.${POSTER_FORMAT}"
      else
        extract_poster "$src" "$w" "$h" \
          "$OUT_DIR/desktop/${SLUG}-${w}w-poster.${POSTER_FORMAT}"
      fi
    fi
  done

  if [[ "$DO_THUMBNAILS" == true ]]; then
    local thumb_out="$OUT_DIR/desktop/${SLUG}-thumb.webp"
    if [[ -n "$THUMB_SRC_OVERRIDE" ]]; then
      encode_thumbnail "$THUMB_SRC_OVERRIDE" "$thumb_out"
    elif [[ -n "$poster_src" ]]; then
      encode_thumbnail "$poster_src" "$thumb_out"
    else
      if should_encode "$thumb_out"; then
        local tmp_thumb
        tmp_thumb="$(mktemp /tmp/compress_thumb_XXXXXX).png"
        local tw="$THUMB_WIDTH"
        local th=$(( THUMB_WIDTH * 9 / 16 ))
        ffmpeg -loglevel error \
          -i "$src" \
          -vf "select=eq(n\\,${POSTER_FRAME}),scale=${tw}:${th}:flags=lanczos" \
          -frames:v 1 -update 1 -y "$tmp_thumb"
        encode_thumbnail "$tmp_thumb" "$thumb_out"
        rm -f "$tmp_thumb"
      else
        log_skip "$(basename "$thumb_out")"
      fi
    fi
  fi
}

# ── Mobile pipeline ─────────────────────────────────────────────────────────────

process_mobile_images() {
  local src
  if ! src="$(find_source_image "$SOURCES_DIR" "mobile")"; then
    log_warn "No mobile source image found in $SOURCES_DIR — skipping mobile images"
    return
  fi
  log_section "Mobile images  ←  $(basename "$src")"

  if [[ "$src" == *.svg || "$src" == *.SVG ]]; then
    local dest="$OUT_DIR/mobile/${SLUG}.svg"
    ensure_dir "$dest"
    log_item "SVG source — copying as-is (no resize ladder)"
    cp "$src" "$dest"
    log_ok "${SLUG}.svg"
    return
  fi

  local i
  for (( i=0; i<${#MOBILE_WIDTHS[@]}; i++ )); do
    local w="${MOBILE_WIDTHS[$i]}" h="${MOBILE_HEIGHTS[$i]}"
    encode_image "$src" "$w" "$h" \
      "$OUT_DIR/mobile/${SLUG}-${w}w.${IMG_FORMAT}"
  done
}

process_mobile_video() {
  local src=""
  for ext in mov mp4 MP4 MOV; do
    if [[ -f "$SOURCES_DIR/mobile.$ext" ]]; then
      src="$SOURCES_DIR/mobile.$ext"
      break
    fi
  done
  if [[ -z "$src" ]]; then
    log_warn "No mobile source video found (expected mobile.mov or mobile.mp4) — skipping"
    return
  fi
  log_section "Mobile video  ←  $(basename "$src")"

  local mobile_widths=("${MOBILE_WIDTHS[@]}")
  local mobile_heights=("${MOBILE_HEIGHTS[@]}")

  local i
  for (( i=0; i<${#mobile_widths[@]}; i++ )); do
    local w="${mobile_widths[$i]}" h="${mobile_heights[$i]}"

    if [[ "$DO_VIDEO" == true ]]; then
      encode_video_all_codecs "$src" "$w" "$h" "$OUT_DIR/mobile" "$SLUG"
    fi

    if [[ "$DO_POSTERS" == true ]]; then
      extract_poster "$src" "$w" "$h" \
        "$OUT_DIR/mobile/${SLUG}-${w}w-poster.${POSTER_FORMAT}"
    fi
  done
}

# ── Device pipeline ─────────────────────────────────────────────────────────────

process_device_video() {
  local src=""
  for ext in mov mp4 MP4 MOV; do
    if [[ -f "$SOURCES_DIR/device.$ext" ]]; then
      src="$SOURCES_DIR/device.$ext"
      break
    fi
  done
  [[ -z "$src" ]] && return 0  # device source is optional

  # Read native dimensions from source
  local dims
  dims="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$src")"
  local w h
  w="$(echo "$dims" | cut -d',' -f1)"
  h="$(echo "$dims" | cut -d',' -f2)"

  log_section "Device video  ←  $(basename "$src")  (${w}×${h})"

  local poster_src
  poster_src="$(find_source_poster "$SOURCES_DIR")" || true

  if [[ "$DO_VIDEO" == true ]]; then
    encode_video_all_codecs "$src" "$w" "$h" "$OUT_DIR/device" "$SLUG"
  fi

  if [[ "$DO_POSTERS" == true ]]; then
    if [[ -n "$poster_src" ]]; then
      encode_image "$poster_src" "$w" "$h" "$OUT_DIR/device/${SLUG}-${w}w-poster.${POSTER_FORMAT}"
    else
      extract_poster "$src" "$w" "$h" "$OUT_DIR/device/${SLUG}-${w}w-poster.${POSTER_FORMAT}"
    fi
  fi

  if [[ "$DO_THUMBNAILS" == true ]]; then
    local thumb_out="$OUT_DIR/device/${SLUG}-thumb.webp"
    if [[ -n "$THUMB_SRC_OVERRIDE" ]]; then
      encode_thumbnail "$THUMB_SRC_OVERRIDE" "$thumb_out"
    else
      local tw="$THUMB_WIDTH" th=$(( THUMB_WIDTH * h / w ))
      if should_encode "$thumb_out"; then
        local tmp_thumb
        tmp_thumb="$(mktemp /tmp/compress_thumb_XXXXXX).png"
        ffmpeg -loglevel error \
          -i "$src" \
          -vf "select=eq(n\\,${POSTER_FRAME}),scale=${tw}:${th}:flags=lanczos" \
          -frames:v 1 -update 1 -y "$tmp_thumb"
        encode_thumbnail "$tmp_thumb" "$thumb_out"
        rm -f "$tmp_thumb"
      else
        log_skip "$(basename "$thumb_out")"
      fi
    fi
  fi
}

# ── Main ────────────────────────────────────────────────────────────────────────

main() {
  echo -e "\n${BOLD}compress.sh${RESET}  →  slug: ${BOLD}${SLUG}${RESET}"
  echo -e "${DIM}sources:  $SOURCES_DIR${RESET}"
  echo -e "${DIM}output:   $OUT_DIR${RESET}"
  echo -e "${DIM}force:    $FORCE${RESET}\n"

  check_deps

  THUMB_SRC_OVERRIDE=""
  if THUMB_SRC_OVERRIDE="$(find_source_thumbnail "$SOURCES_DIR")"; then
    log_warn "Thumbnail override  ←  $(basename "$THUMB_SRC_OVERRIDE")"
  fi

  if [[ ! -d "$SOURCES_DIR" ]]; then
    log_error "Source directory not found: $SOURCES_DIR"
    echo "  Create it and add your source files:"
    echo "    src/$SLUG/desktop.<ext>   (image)"
    echo "    src/$SLUG/desktop.mov     (video)"
    echo "    src/$SLUG/poster.<ext>    (video poster override)"
    echo "    src/$SLUG/thumbnail.<ext> (tab thumbnail override — any slide type)"
    echo "    src/$SLUG/mobile.<ext>    (image)"
    echo "    src/$SLUG/mobile.mov      (video)"
    exit 1
  fi

  if [[ "$DO_DESKTOP" == true ]]; then
    [[ "$DO_IMAGES" == true || "$DO_THUMBNAILS" == true ]] && process_desktop_images
    [[ "$DO_VIDEO" == true || "$DO_POSTERS" == true || "$DO_THUMBNAILS" == true ]] && process_desktop_video
  fi

  if [[ "$DO_MOBILE" == true ]]; then
    [[ "$DO_IMAGES" == true ]] && process_mobile_images
    [[ "$DO_VIDEO" == true || "$DO_POSTERS" == true ]] && process_mobile_video
  fi

  [[ "$DO_VIDEO" == true || "$DO_POSTERS" == true || "$DO_THUMBNAILS" == true ]] && process_device_video

  echo -e "\n${BOLD}${GREEN}Done.${RESET}  Output → $OUT_DIR\n"
}

main

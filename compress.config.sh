#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  compress.config.sh — Tunable settings for the media pipeline               ║
# ║  Edit this file to adjust quality, codecs, and behaviour.                   ║
# ║  Do not edit compress.sh unless you need to change pipeline logic.          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝


# ── Image ───────────────────────────────────────────────────────────────────────

# Output format for still images: avif | webp | png
IMG_FORMAT="webp"

# Lossless encode — true = pixel-perfect, no quality loss, larger files.
# Set to false and tune IMG_QUALITY to enable lossy compression.
IMG_LOSSLESS=true

# Quality (0–100, higher = better). Only used when IMG_LOSSLESS=false.
#   AVIF  85–92  is visually transparent for photographic content
#   WebP  80–90  is the typical sweet-spot
IMG_QUALITY=90

# AVIF encoding speed (0 = slowest/best compression, 10 = fastest).
# Lower values produce smaller files at the same visual quality.
# 4–6 is a practical balance; use 0–2 for final production encodes.
IMG_AVIF_SPEED=4

# Downscale filter kernel — Lanczos is the gold standard for sharp downsampling.
# Options (ImageMagick names): Lanczos | Mitchell | CatRom | Sinc
IMG_FILTER="Lanczos"

# Strip EXIF / ICC metadata from output images.
# true = smaller files; false = preserves colour profiles (useful for print).
IMG_STRIP_METADATA=true


# ── Video ───────────────────────────────────────────────────────────────────────

# Codecs to produce — space-separated subset of: h264 h265 vp9 av1
#   h264  →  .mp4   Universal fallback (every browser since 2012)
#   h265  →  .mp4   ~40% smaller than h264; Safari + modern desktop Chrome
#   vp9   →  .webm  Chrome / Firefox / Edge royalty-free option
#   av1   →  .mp4   Best ratio; all modern browsers, slow to encode
VID_CODECS="h264 h265 vp9"

# Lossless video — true sets CRF to 0 (pixel-perfect, very large files).
# Useful for inspecting a resize before committing to a quality setting.
# Set to false and tune VID_CRF_* for real delivery.
VID_LOSSLESS=false

# CRF values used when VID_LOSSLESS=false (lower = better, larger file):
#   H.264  sane range 17–23  (transcode.sh reference: 19 — near-lossless for portfolio)
#   H.265  sane range 18–26  (transcode.sh reference: 22 — ~same PSNR as H.264 at ~6 CRF lower)
#   VP9    sane range 24–36  (transcode.sh reference: 29 — constrained-quality, -b:v 0 required)
#   AV1    sane range 20–35  (libaom scale, subjectively similar to H.265)
VID_CRF_H264=19
VID_CRF_H265=22
VID_CRF_VP9=29
VID_CRF_AV1=28

# Encoding preset — affects speed vs. compression efficiency, not quality.
# h264/h265: ultrafast | superfast | veryfast | faster | fast | medium | slow | veryslow
# vp9:       realtime | good | best  (mapped from this value automatically)
# av1:       0 (slowest) – 13 (fastest)  (mapped from this value automatically)
VID_PRESET="slow"

# Output frame rate. "source" keeps the original; or set a number e.g. 30 / 24.
VID_FPS="source"

# Strip the audio track from output (true for silent portfolio loops).
VID_NO_AUDIO=true

# Move the moov atom to the front of the file for instant browser playback.
VID_FASTSTART=true


# ── Poster (video → still frame) ────────────────────────────────────────────────

# Format for poster stills extracted from video: avif | webp | jpg | png
POSTER_FORMAT="webp"

# Lossless poster encode. false + POSTER_QUALITY is typical for delivery.
POSTER_LOSSLESS=true

# Quality (0–100) when POSTER_LOSSLESS=false.
POSTER_QUALITY=92

# Source frame index to use as the poster (0 = first frame).
POSTER_FRAME=0


# ── Thumbnail ────────────────────────────────────────────────────────────────────

# Actual pixel width of thumbnail (200px CSS × 3x DPR = 600px)
THUMB_WIDTH=600

# Lossless thumbnail — false recommended (thumbnails are small, lossy is fine)
THUMB_LOSSLESS=false

# Quality when THUMB_LOSSLESS=false (0–100)
THUMB_QUALITY=85

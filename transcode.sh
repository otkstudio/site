#!/bin/sh
# Script accepts three arguments: input file, width in pixels of output video, and output folder
# Check that all arguments are passed
if [ $# -ne 3 ]; then
    echo "Example usage: optvideo input.mp4 1920 output_folder"
    exit 1
fi

# Get the filename without the file extension
FILENAME=${1%%.*}

ffmpeg -i $1 -c:v libx264 -crf 24 -vf scale=$2:-2 -movflags faststart -an $3/${FILENAME}_h264.mp4
ffmpeg -i $1 -c:v libvpx-vp9 -crf 36 -deadline best -vf scale=$2:-2 -an $3/${FILENAME}.webm
ffmpeg -i $1 -c:v libx265 -crf 28 -preset veryslow -vf scale=$2:-2 -tag:v hvc1 -movflags faststart -an $3/${FILENAME}_h265.mp4

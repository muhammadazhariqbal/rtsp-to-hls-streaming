#!/bin/bash

RTSP_URL=${RTSP_URL:-"rtsp://host.docker.internal:8554/mystream"}

echo "Recording 20-minute MP4 segments from: $RTSP_URL"

mkdir -p /app/recordings

exec ffmpeg -rtsp_transport tcp \
    -i "$RTSP_URL" \
    -c copy \
    -f segment \
    -segment_time 1200 \
    -reset_timestamps 1 \
    /app/recordings/recording_%03d.mp4

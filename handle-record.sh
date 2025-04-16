#!/bin/bash

RTSP_URL=${RTSP_URL:-"rtsp://host.docker.internal:8554/mystream"}
SEGMENT_TIME=${SEGMENT_TIME:-1200}  # 4 minutes

echo "📼 Recording segments from: $RTSP_URL"
echo "⏱️ Segment duration: $SEGMENT_TIME seconds"

mkdir -p /app/recordings

exec ffmpeg -rtsp_transport tcp \
    -i "$RTSP_URL" \
    -c:v libx264 -preset veryfast -crf 23 \
    -c:a aac -b:a 128k \
    -f segment \
    -segment_time "$SEGMENT_TIME" \
    -reset_timestamps 1 \
    -movflags +faststart \
    /app/recordings/recording_%03d.mp4

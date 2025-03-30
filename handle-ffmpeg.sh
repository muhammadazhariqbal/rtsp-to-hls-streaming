#!/bin/bash

# Use provided RTSP URL or fall back to default
RTSP_URL=${RTSP_URL:-"rtsp://host.docker.internal:8554/mystream"}

echo "Starting RTSP to HLS conversion from: $RTSP_URL"

# Run FFmpeg with the provided RTSP URL
exec ffmpeg -rtsp_transport tcp -i "$RTSP_URL" \
    -c:v copy -f hls \
    -hls_time 4 \
    -hls_list_size 0 \
    -hls_segment_filename /app/output/segment_%03d.ts \
    -strftime 1 \
    -hls_segment_type mpegts \
    /app/output/stream.m3u8
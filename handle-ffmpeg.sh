#!/bin/bash

# Use provided RTSP URL or fall back to default
RTSP_URL=${RTSP_URL:-"rtsp://host.docker.internal:8554/mystream"}

echo "Starting low-latency RTSP to HLS conversion from: $RTSP_URL"

# Run FFmpeg with low-latency flags
exec ffmpeg -rtsp_transport tcp \
    -fflags nobuffer -flags low_delay -probesize 32 -analyzeduration 0 \
    -i "$RTSP_URL" \
    -c:v copy -f hls \
    -hls_time 1 \
    -hls_list_size 3 \
    -hls_flags delete_segments+append_list+omit_endlist \
    -hls_segment_filename /app/output/segment_%03d.ts \
    -hls_segment_type mpegts \
    /app/output/stream.m3u8

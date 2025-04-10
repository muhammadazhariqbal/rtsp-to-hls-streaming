#!/bin/bash

# Use provided RTSP URL or fall back to default
RTSP_URL=${RTSP_URL:-"rtsp://host.docker.internal:8554/mystream"}

# Use provided SEGMENT_TIME or default to 1200 seconds (20 minutes)
SEGMENT_TIME=${SEGMENT_TIME:-1200}  # Default 20 minutes if not provided

echo "📼 Recording segments from: $RTSP_URL"
echo "⏱️ Segment duration: $SEGMENT_TIME seconds"

# Create output directory for recordings
mkdir -p /app/recordings

# Start FFmpeg to record RTSP stream into 20-minute segments (or custom time)
exec ffmpeg -rtsp_transport tcp \
    -i "$RTSP_URL" \
    -c copy \
    -f segment \
    -segment_time "$SEGMENT_TIME" \
    -reset_timestamps 1 \
    /app/recordings/recording_%03d.mp4

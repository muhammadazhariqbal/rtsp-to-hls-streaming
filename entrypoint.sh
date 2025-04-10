#!/bin/bash
set -e  # Exit if any command fails

# Check if NGROK_AUTHTOKEN is provided
if [ -z "$NGROK_AUTHTOKEN" ]; then
  echo "Warning: NGROK_AUTHTOKEN not provided. Public URL will not be available."
  ENABLE_NGROK=false
else
  ENABLE_NGROK=true
  # Configure ngrok with auth token
  ngrok config add-authtoken $NGROK_AUTHTOKEN
fi

echo "Starting FFmpeg processing..."
/app/handle-ffmpeg.sh &
FFMPEG_PID=$!

# Start MP4 recording
/app/handle-record.sh &
RECORD_PID=$!

# Wait a moment to ensure FFmpeg starts properly
sleep 2

# Check if FFmpeg is still running
if kill -0 $FFMPEG_PID 2>/dev/null; then
    echo "FFmpeg started successfully! Starting HTTP Server..."
    /app/handle-server.sh &
    SERVER_PID=$!
    
    # Wait for HTTP server to start
    sleep 2
    
    # Start ngrok if enabled
    if [ "$ENABLE_NGROK" = true ]; then
      echo "Starting ngrok tunnel..."
      /app/handle-ngrok.sh &
      NGROK_PID=$!
    fi
else
    echo "FFmpeg failed to start properly. Exiting."
    exit 1
fi

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
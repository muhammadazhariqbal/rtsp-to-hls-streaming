#!/bin/bash

echo "Launching ngrok tunnel to port 8081..."

# Start ngrok in background
ngrok http 8081 --log=stdout > /app/ngrok.log 2>&1 &
NGROK_PID=$!

# Give ngrok a moment to establish connection
sleep 5

# Extract and display the public URL
echo "Fetching public URL from ngrok API..."
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | grep -o 'https://[^"]*')

if [ -n "$NGROK_URL" ]; then
  echo "=================================================="
  echo "🌐 Public HLS Stream URL: ${NGROK_URL}/stream.m3u8"
  echo "=================================================="
  echo "${NGROK_URL}/stream.m3u8" > /app/output/ngrok-url.txt
else
  echo "Failed to retrieve ngrok URL. Check /app/ngrok.log for details."
fi

# Keep ngrok running
wait $NGROK_PID
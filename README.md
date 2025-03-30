# RTSP to HLS Converter with Public Streaming

This document provides comprehensive documentation for the RTSP to HLS Converter project, which allows you to capture an RTSP video stream, convert it to HLS format for web compatibility, and expose it to the internet through ngrok.

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Project Structure](#project-structure)
5. [Component Details](#component-details)
6. [Building and Running](#building-and-running)
7. [Configuration Options](#configuration-options)
8. [Accessing the Stream](#accessing-the-stream)
9. [Troubleshooting](#troubleshooting)
10. [Security Considerations](#security-considerations)
11. [Performance Optimization](#performance-optimization)

## Project Overview

This project creates a containerized solution for:
- Capturing real-time video from RTSP sources (IP cameras, streaming servers, etc.)
- Converting the RTSP stream to HLS (HTTP Live Streaming) format with FFmpeg
- Serving the HLS stream via a simple HTTP server
- Exposing the stream to the internet with a public URL using ngrok
- Storing all video segments for archival purposes

HLS is widely supported by web browsers and mobile devices, making it ideal for broad compatibility.

## Architecture

The solution uses a multi-process architecture within a single Docker container:

```
┌─────────────────────────────────────────────────────┐
│                   Docker Container                  │
│                                                     │
│  ┌─────────┐    ┌─────────┐    ┌─────────────────┐  │
│  │  FFmpeg │    │  HTTP   │    │      ngrok      │  │
│  │ Process │───▶│ Server  │◀───│     Tunnel      │  │
│  │         │    │         │    │                 │  │
│  └─────────┘    └─────────┘    └─────────────────┘  │
│       │             ▲                  ▲            │
│       │             │                  │            │
│       ▼             │                  │            │
│  ┌─────────┐        │                  │            │
│  │ /app/   │        │                  │            │
│  │ output/ │────────┘                  │            │
│  └─────────┘                           │            │
│                                        │            │
└────────────────────────────────────────┼────────────┘
                                         │
                                         ▼
                               External Public Access
```

1. **FFmpeg Process**: Captures RTSP stream and converts it to HLS format
2. **HTTP Server**: Serves the HLS files (.m3u8 playlist and .ts segments)
3. **ngrok Tunnel**: Creates a secure tunnel to expose the HTTP server publicly
4. **/app/output/**: Directory where all HLS files are stored

## Prerequisites

- Docker installed on your host system
- An RTSP stream source (camera, media server, etc.)
- ngrok account and authtoken (free tier works for testing)

## Project Structure

```
project/
├── output/                  # Empty directory for HLS output files
├── Dockerfile               # Container definition
├── entrypoint.sh            # Main entry script
├── handle-ffmpeg.sh         # Script for RTSP to HLS conversion
├── handle-server.sh         # Script for HTTP server
└── handle-ngrok.sh          # Script for ngrok tunneling
```

## Component Details

### Dockerfile

```dockerfile
# Use Ubuntu 22.04 LTS as the base image
FROM ubuntu:22.04

# Install system dependencies
RUN apt update && apt install -y curl ffmpeg unzip wget

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt install -y nodejs \
    && npm install -g http-server

# Install ngrok
RUN wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
    && tar xvzf ngrok-v3-stable-linux-amd64.tgz -C /usr/local/bin \
    && rm ngrok-v3-stable-linux-amd64.tgz

# Set working directory
WORKDIR /app

# Create output directory
RUN mkdir -p /app/output && chmod 777 /app/output

# Copy necessary files
COPY output /app/output
COPY entrypoint.sh /app/entrypoint.sh
COPY handle-ffmpeg.sh /app/handle-ffmpeg.sh
COPY handle-server.sh /app/handle-server.sh
COPY handle-ngrok.sh /app/handle-ngrok.sh

# Make scripts executable
RUN chmod +x /app/entrypoint.sh /app/handle-ffmpeg.sh /app/handle-server.sh /app/handle-ngrok.sh

# Expose HTTP server port
EXPOSE 8081
# Expose ngrok API port
EXPOSE 4040

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
```

The Dockerfile:
- Uses Ubuntu 22.04 LTS as the base image
- Installs FFmpeg for video processing
- Installs Node.js and http-server for serving files
- Installs ngrok for creating the public tunnel
- Sets up the necessary directory structure
- Makes all script files executable
- Exposes ports 8081 (HTTP server) and 4040 (ngrok admin interface)

### entrypoint.sh

```bash
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
```

The entrypoint script:
- Checks if an ngrok auth token was provided
- Starts FFmpeg in the background and verifies it's running
- Launches the HTTP server if FFmpeg started successfully
- Starts ngrok to create a public tunnel if auth token is available
- Waits for any process to exit and exits with the same status code

### handle-ffmpeg.sh

```bash
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
```

The FFmpeg handler script:
- Accepts a customizable RTSP URL via environment variable
- Falls back to a default URL if none provided
- Uses TCP transport for RTSP (better for unreliable networks)
- Copies the video codec without re-encoding (low CPU usage)
- Creates 4-second segments for the HLS stream
- Sets list size to 0 to keep all segments in the playlist
- Names segments with sequential numbering (segment_001.ts, etc.)
- Enables timestamp format in filenames
- Specifies MPEG-TS as the segment type
- Creates the main playlist file at /app/output/stream.m3u8

### handle-server.sh

```bash
#!/bin/bash
set -e  # Exit if any command fails

echo "Launching HTTP Server on port 8081..."
exec http-server /app/output -p 8081 --cors
```

The HTTP server script:
- Launches a simple Node.js-based HTTP server
- Serves files from the /app/output directory
- Listens on port 8081
- Enables CORS (Cross-Origin Resource Sharing) for web player compatibility

### handle-ngrok.sh

```bash
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
else
  echo "Failed to retrieve ngrok URL. Check /app/ngrok.log for details."
fi

# Keep ngrok running
wait $NGROK_PID
```

The ngrok handler script:
- Creates an HTTP tunnel to port 8081
- Logs ngrok output to /app/ngrok.log
- Queries the ngrok API to retrieve the public URL
- Displays the complete HLS stream URL for easy access
- Waits for the ngrok process to complete (keeps it running)

## Building and Running

### Building the Image

```bash
docker build -t rtsp-hls-streamer .
```

### Running the Container

Basic usage with defaults:

```bash
docker run -p 8081:8081 -p 4040:4040 \
  -e NGROK_AUTHTOKEN=your_ngrok_auth_token \
  rtsp-hls-streamer
```

With custom RTSP source:

```bash
docker run -p 8081:8081 -p 4040:4040 \
  -e NGROK_AUTHTOKEN=your_ngrok_auth_token \
  -e RTSP_URL="rtsp://192.168.1.100:554/stream" \
  rtsp-hls-streamer
```

With volume for persistent storage:

```bash
docker run -p 8081:8081 -p 4040:4040 \
  -e NGROK_AUTHTOKEN=your_ngrok_auth_token \
  -v $(pwd)/stream-output:/app/output \
  rtsp-hls-streamer
```

## Configuration Options

| Environment Variable | Description | Default Value |
|---------------------|-------------|---------------|
| `RTSP_URL` | URL of the RTSP stream to capture | rtsp://host.docker.internal:8554/mystream |
| `NGROK_AUTHTOKEN` | Authentication token for ngrok | (required for public URL) |

## Accessing the Stream

### Local Access

The HLS stream is available locally at:
```
http://localhost:8081/stream.m3u8
```

### Public Access

When ngrok is running, the container will display a public URL in the logs. The URL will look like:
```
https://abc123def456.ngrok.io/stream.m3u8
```

This URL can be shared and accessed from any device with internet access.

### ngrok Web Interface

The ngrok web interface is available at:
```
http://localhost:4040
```

This interface shows:
- Active tunnels
- Request/response details
- Traffic statistics
- Error logs

## Troubleshooting

### Common Issues

1. **FFmpeg fails to start:**
   - Check if the RTSP source is accessible
   - Verify the RTSP URL format
   - For local RTSP servers, use `host.docker.internal` instead of `localhost`
   - On Linux, add `--add-host=host.docker.internal:host-gateway` to the docker run command

2. **No public URL appears:**
   - Verify your ngrok auth token is correct
   - Check `/app/ngrok.log` for errors
   - Ensure port 4040 is not already in use

3. **Stream not playing in browser:**
   - Verify the HLS playlist is being created (`/app/output/stream.m3u8`)
   - Check if segment files are being generated
   - Try an HLS-compatible player like VLC or a web player using hls.js

### Checking Logs

```bash
# View container logs
docker logs container_name

# Access shell in the container
docker exec -it container_name /bin/bash

# View ngrok logs
docker exec -it container_name cat /app/ngrok.log
```

## Security Considerations

- The ngrok free tier assigns random URLs each session
- For persistent, custom URLs, consider ngrok Pro
- The HLS stream is publicly accessible to anyone with the URL
- Consider adding authentication for production use
- Store ngrok auth tokens securely (not in command line history)

## Performance Optimization

- If CPU usage is high, consider using hardware acceleration:
  ```
  -hwaccel auto
  ```
- For better bandwidth efficiency, you can add transcoding:
  ```
  -c:v libx264 -preset fast -crf 23
  ```
- Adjust segment duration (`-hls_time`) for different latency/quality tradeoffs
- For limited storage, set `-hls_list_size` to a positive value (e.g., 10)
- Add `-hls_flags delete_segments` if you don't need to keep all segments

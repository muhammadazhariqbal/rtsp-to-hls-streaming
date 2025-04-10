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
COPY handle-record.sh /app/handle-record.sh

# Make scripts executable
RUN chmod +x /app/entrypoint.sh /app/handle-ffmpeg.sh /app/handle-server.sh /app/handle-ngrok.sh /app/handle-record.sh

# Expose HTTP server port
EXPOSE 8081
# Expose ngrok API port (not actually exposed outside the container, but documented)
EXPOSE 4040

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
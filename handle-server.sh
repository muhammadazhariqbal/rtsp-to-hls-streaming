#!/bin/bash
set -e  # Exit if any command fails

echo "Launching HTTP Server on port 8081..."
exec http-server /app/output -p 8081 --cors
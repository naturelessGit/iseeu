#!/bin/bash

# Prompt for port
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

# Define paths
LOG_DIR="$HOME/iseeu/logs"
LOG_FILE="$LOG_DIR/log_$(date '+%Y-%m-%d_%H-%M-%S').txt"
CF_LOG="$HOME/iseeu/cf_output.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Clean up function
cleanup() {
    echo -e "\n[!] Cleaning up..."
    pkill -f "python3 -m http.server $PORT"
    pkill -f cloudflared
    rm -f "$CF_LOG"
    echo "[✓] All processes killed. Logs saved at: $LOG_FILE"
    exit
}

# Trap Ctrl+C
trap cleanup INT

echo "[*] Killing old servers..."
pkill -f "python3 -m http.server $PORT" 2>/dev/null
pkill -f cloudflared 2>/dev/null

echo "[*] Creating minimal HTML..."
cat > index.html <<EOF
<html><head><title>iSeeU</title></head><body><h1>You got Rickrolled 🎣</h1>
<iframe width="100%" height="400" src="https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1" frameborder="0" allow="autoplay; encrypted-media" allowfullscreen></iframe>
</body></html>
EOF

echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > "$LOG_FILE" 2>&1 &

echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" > "$CF_LOG" 2>&1 &

# Wait for Cloudflared to print the public URL
echo "[*] Waiting for Cloudflared URL..."
for i in {1..10}; do
    sleep 2
    PUBLIC_URL=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" "$CF_LOG" | head -n1)
    if [ ! -z "$PUBLIC_URL" ]; then
        echo "[✓] Public URL: $PUBLIC_URL"
        echo "[*] Logging to $LOG_FILE..."
        echo "[✓] Public URL: $PUBLIC_URL" >> "$LOG_FILE"
        break
    fi
done

if [ -z "$PUBLIC_URL" ]; then
    echo "[✗] Failed to get public URL."
    cleanup
fi

echo "[*] Press Ctrl+C to stop."

# Wait until Ctrl+C
while true; do sleep 1; done
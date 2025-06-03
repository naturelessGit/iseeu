#!/data/data/com.termux/files/usr/bin/bash

PORT=8080
WEB_DIR=~/webpage
LOG_FILE=~/cloudflared.log

echo "[*] Checking if port $PORT is in use..."
PID=$(lsof -t -i:$PORT 2>/dev/null)

if [ -n "$PID" ]; then
    echo "[*] Killing process on port $PORT (PID $PID)..."
    kill -9 "$PID"
    sleep 1
fi

echo "[*] Making sure $WEB_DIR exists..."
mkdir -p "$WEB_DIR"
cd "$WEB_DIR" || exit 1

echo "[*] Starting Python HTTP server..."
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!
sleep 2
echo "[+] Python server running on localhost:$PORT (PID $SERVER_PID)"

echo "[*] Starting Cloudflare tunnel..."
cloudflared tunnel --url http://localhost:$PORT > "$LOG_FILE" 2>&1 &
CLOUD_PID=$!

sleep 8

echo "[*] Extracting tunnel URL..."
URL=$(grep -oE 'https://[a-z0-9\-]+\.trycloudflare\.com' "$LOG_FILE" | head -n 1)

if [ -n "$URL" ]; then
    echo "[✓] Tunnel is ready:"
    echo "$URL"
else
    echo "[✗] Failed to get tunnel URL."
    kill $SERVER_PID $CLOUD_PID 2>/dev/null
    exit 1
fi

echo "[*] Press Ctrl+C to stop."
trap 'echo "[*] Stopping..."; kill $SERVER_PID $CLOUD_PID 2>/dev/null' EXIT
wait
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

echo "[*] Ensuring $WEB_DIR exists..."
mkdir -p "$WEB_DIR"
cd "$WEB_DIR" || { echo "[✗] Failed to change directory."; exit 1; }

echo "[*] Starting local HTTP server on port $PORT..."
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!
sleep 2

if ! ps -p $SERVER_PID > /dev/null; then
    echo "[✗] Failed to start local server."
    exit 1
fi

echo "[+] HTTP server running (PID $SERVER_PID)."

echo "[*] Starting Cloudflare Tunnel..."
cloudflared tunnel --url http://localhost:$PORT > "$LOG_FILE" 2>&1 &
CLOUD_PID=$!

sleep 8

echo "[*] Extracting tunnel URL..."
URL=$(grep -oE 'https://[a-z0-9\-]+\.trycloudflare\.com' "$LOG_FILE" | head -n 1)
ERROR_CODE=$(grep -oE 'error code: [0-9]+' "$LOG_FILE" | head -n 1)

if [ -n "$URL" ]; then
    echo "[✓] Tunnel is live:"
    echo "$URL"
elif [ -n "$ERROR_CODE" ]; then
    echo "[✗] Cloudflare Tunnel failed with $ERROR_CODE"
    kill $SERVER_PID $CLOUD_PID 2>/dev/null
    exit 1
else
    echo "[✗] Tunnel failed to start. See $LOG_FILE for details."
    kill $SERVER_PID $CLOUD_PID 2>/dev/null
    exit 1
fi

echo "[*] Press Ctrl+C to stop everything."
trap 'echo "[*] Shutting down..."; kill $SERVER_PID $CLOUD_PID 2>/dev/null; exit' INT
wait

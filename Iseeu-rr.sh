#!/data/data/com.termux/files/usr/bin/bash

PORT=8080
WEB_DIR=~/webpage
LOG_FILE=~/ngrok.log

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

echo "[*] Starting ngrok tunnel..."
# Start ngrok in the background and save the PID
ngrok http $PORT > "$LOG_FILE" 2>&1 &
NGROK_PID=$!

sleep 5

echo "[*] Getting public URL from ngrok API..."
URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE 'https://[a-z0-9\-]+\.ngrok-free\.app' | head -n 1)

if [ -n "$URL" ]; then
    echo "[✓] Tunnel is ready:"
    echo "$URL"
else
    echo "[✗] Failed to get ngrok URL."
    kill $SERVER_PID $NGROK_PID 2>/dev/null
    exit 1
fi

echo "[*] Press Ctrl+C to stop."
trap 'echo "[*] Stopping..."; kill $SERVER_PID $NGROK_PID 2>/dev/null' EXIT
wait
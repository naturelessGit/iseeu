#!/data/data/com.termux/files/usr/bin/bash

PORT=8080
WEB_DIR=~/webpage
LOG_FILE=~/ngrok.log
NGROK_CONFIG="$HOME/.config/ngrok/ngrok.yml"

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

echo "[*] Checking ngrok installation..."
if ! grep -q "authtoken" "$NGROK_CONFIG" 2>/dev/null; then
    echo "[✗] ngrok not authenticated. Add your token using:"
    echo "    ngrok config add-authtoken <your_token>"
    kill $SERVER_PID
    exit 1
fi

echo "[*] Starting ngrok tunnel..."
ngrok http $PORT > "$LOG_FILE" 2>&1 &
NGROK_PID=$!

# Wait for ngrok API to be ready (max 10s)
echo "[*] Waiting for ngrok API..."
for i in {1..10}; do
    URL=$(curl -s http://localhost:4040/api/tunnels | grep -oE 'https://[a-z0-9\-]+\.ngrok.io' | head -n 1)
    if [ -n "$URL" ]; then break; fi
    sleep 1
done

if [ -n "$URL" ]; then
    echo "[✓] Tunnel is ready:"
    echo "$URL"
else
    echo "[✗] Failed to get ngrok URL after waiting."
    echo "--- ngrok log output ---"
    tail -n 10 "$LOG_FILE"
    kill $SERVER_PID $NGROK_PID 2
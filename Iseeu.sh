#!/bin/bash

# === Config ===
BOT_TOKEN="7469902610:AAE2ySw1EEMBI1lUP0JmSp_VnLi2Q3oyaJU"
CHAT_ID="8155138245"
DEVICE_LOG="$HOME/iseeu/devices.log"
LOG_DIR="$HOME/iseeu/logs"
HTML_FILE="$HOME/iseeu/index.html"
SERVER_PID=""
TUNNEL_PID=""
CLOUDFLARE_LOG="$HOME/iseeu/cf_output.log"

mkdir -p "$LOG_DIR"

# === Prompt Port ===
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

# === Kill Previous Processes ===
echo "[*] Killing old servers..."
pkill -f "python3 -m http.server $PORT"
pkill -f cloudflared

# === Create HTML File ===
echo "[*] Creating minimal HTML..."
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>ISEEU</title></head><body>
<h1>Welcome</h1><p>This is a demo.</p>
</body></html>
EOF

# === Start HTTP Server ===
echo "[*] Starting HTTP server on port $PORT..."
cd "$HOME/iseeu"
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!

# === Start Cloudflared Tunnel ===
echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url http://localhost:$PORT --logfile "$CLOUDFLARE_LOG" > "$CLOUDFLARE_LOG" 2>&1 &
TUNNEL_PID=$!

sleep 5

# === Extract Public URL ===
PUBLIC_URL=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$CLOUDFLARE_LOG" | head -n 1)

if [[ -z "$PUBLIC_URL" ]]; then
  echo "[✗] Failed to get public URL."
  kill "$SERVER_PID" "$TUNNEL_PID"
  exit 1
fi

echo "[✓] Public URL: $PUBLIC_URL"

# === Log Device ===
DEVICE_NAME=$(uname -a | cut -d' ' -f2)
echo "$DEVICE_NAME" >> "$DEVICE_LOG"

# === Send Telegram Message ===
MESSAGE="ISEEU-INFO:%0A💻 Devices Used:%0A$(cat $DEVICE_LOG 2>/dev/null || echo 'devices.log not found.')"
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$MESSAGE" > /dev/null

# === Log All to File ===
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
FULL_LOG="$LOG_DIR/log_$TIMESTAMP.txt"
echo "[*] Logging to $FULL_LOG..."
echo "Server started at: $PUBLIC_URL" > "$FULL_LOG"
cat "$CLOUDFLARE_LOG" >> "$FULL_LOG"

# === Handle Ctrl+C ===
cleanup() {
  echo "[*] Cleaning up..."
  kill "$SERVER_PID" "$TUNNEL_PID" 2>/dev/null
  rm -f "$CLOUDFLARE_LOG"
  echo "[*] Done."
  exit 0
}
trap cleanup INT

# === Keep Alive ===
echo "[*] Press Ctrl+C to stop."
while true; do sleep 1; done
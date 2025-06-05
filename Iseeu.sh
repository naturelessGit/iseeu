#!/bin/bash

# === Prompt for Port ===
read -p "[?] Enter port to use for local server (default 8080): " PORT
PORT=${PORT:-8080}

# === Setup Directories ===
LOG_DIR="$HOME/iseeu/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/log_$(date '+%Y-%m-%d_%H-%M-%S').txt"

# === Clean up Function ===
cleanup() {
    echo -e "\n[*] Cleaning up..."
    pkill -f "python3 -m http.server"
    pkill -f "cloudflared"
    echo "[*] Server and tunnel stopped."
    exit 0
}
trap cleanup INT

# === Kill Old Services ===
echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" 2>/dev/null
pkill -f "cloudflared" 2>/dev/null

# === Minimal HTML ===
echo "[*] Creating minimal HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
  <head><title>ISEEU</title></head>
  <body><h2>ISEEU</h2><p>This is a test page.</p></body>
</html>
EOF

# === Start HTTP Server ===
echo "[*] Starting HTTP server on port $PORT..."
python3 -m http.server "$PORT" > "$LOG_FILE" 2>&1 &

# === Start Named Cloudflared Tunnel ===
echo "[*] Starting Cloudflared tunnel..."
cloudflared tunnel --url http://localhost:$PORT --name iseeu-tunnel --logfile "$LOG_FILE" &

# === Wait for Tunnel to be Reachable ===
echo "[*] Waiting for tunnel to initialize..."
sleep 10

# === Display Tunnel Info ===
echo "[✓] Tunnel should now be accessible at:"
echo "    https://mysite.com"

# === Live Logging Output ===
echo "[*] Logging to $LOG_FILE..."
echo "[*] Press Ctrl+C to stop."

# === Wait Forever Until Ctrl+C ===
tail -f "$LOG_FILE"
#!/data/data/com.termux/files/usr/bin/bash

trap cleanup INT

function cleanup() {
    echo "[*] Cleaning up..."
    pkill -f "python3 -m http.server"
    pkill -f "cloudflared"
    rm -f index.html
    echo "[*] Done. Exiting."
    exit 0
}

read -p "[?] Enter port to use for local server (default 8080): " port
port=${port:-8080}

echo "[*] Killing old servers..."
pkill -f "python3 -m http.server" &>/dev/null
pkill -f "cloudflared" &>/dev/null

echo "[*] Creating autoplay HTML..."
cat <<EOF > index.html
<!DOCTYPE html>
<html>
<head>
  <title>It Works!</title>
</head>
<body>
  <h1>🔊 Autoplay Test</h1>
  <audio autoplay>
    <source src="https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3" type="audio/mpeg">
    Your browser does not support the audio element.
  </audio>
</body>
</html>
EOF

echo "[*] Starting HTTP server on port $port..."
nohup python3 -m http.server "$port" --bind 127.0.0.1 > /dev/null 2>&1 &

echo "[*] Waiting for HTTP server to be ready..."
until curl -s "http://127.0.0.1:$port" > /dev/null; do
    sleep 1
done

echo "[*] Starting Cloudflared tunnel..."

logfile="logs/log_$(date +'%Y-%m-%d_%H-%M-%S').txt"
mkdir -p logs

nohup cloudflared tunnel \
    --url "http://localhost:$port" \
    --name iseeu-tunnel \
    --logfile "$logfile" \
    --metrics 127.0.0.1:20241 \
    > /dev/null 2>&1 &

echo "[*] Waiting for tunnel to initialize..."
sleep 5

echo "[✓] Tunnel should now be accessible at:"
echo "    https://mysite.com"
echo "[*] Logging to $logfile..."
echo "[*] Press Ctrl+C to stop."

while true; do sleep 1; done
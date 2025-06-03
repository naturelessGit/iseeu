#!/bin/sh

clear
echo "Starting tunnel using npx localtunnel..."
echo "------------------------------------------"

# Global variable to store the public URL
varurl=""

start_npx() {
    if command -v npx >/dev/null 2>&1; then
        npx localtunnel --port 8080 --print-requests > ~/tunnel.log 2>&1 &
        NPX_PID=$!
        sleep 8
        varurl=$(grep -oE "https://[a-zA-Z0-9.-]+\.loca\.lt" ~/tunnel.log | head -n1)
        if [ -z "$varurl" ]; then
            kill $NPX_PID 2>/dev/null
            return 1
        fi
        TUNNEL_PID=$NPX_PID
        return 0
    else
        echo "[✗] npx is not installed. Please install Node.js and run: npm install -g localtunnel"
        exit 1
    fi
}

# Start the tunnel
if start_npx; then
    echo "[✓] Tunnel started via LocalTunnel:"
    echo "     $varurl"
else
    echo "[✗] Failed to start LocalTunnel."
    exit 1
fi

# Start HTTP server
mkdir -p ~/public_html
echo "<h1>Hello from Termux!</h1><p>Your server is up.</p>" > ~/public_html/index.html
cd ~/public_html || exit 1

if command -v python3 >/dev/null 2>&1; then
    python3 -m http.server 8080 >/dev/null 2>&1 &
    SERVER_PID=$!
elif command -v busybox >/dev/null 2>&1; then
    busybox httpd -f -p 8080 &
    SERVER_PID=$!
else
    echo "[✗] No supported web server found (python3 or busybox required)."
    kill $TUNNEL_PID 2>/dev/null
    exit 1
fi

trap 'echo "Cleaning up..."; kill $TUNNEL_PID $SERVER_PID 2>/dev/null' EXIT

echo "[*] Local server running at http://localhost:8080"
echo "[*] Tunnel URL: $varurl"
echo "[*] Press Ctrl+C to stop."
echo "------------------------------------------"

wait

#!/bin/sh

clear
echo "Starting tunnel... (Serveo → Cloudflared → Ngrok → LocalTunnel)"
echo "---------------------------------------------------------------"

# Global variable to store tunnel URL
varurl=""

start_serveo() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -R 80:localhost:8080 serveo.net 2>&1 | tee ~/tunnel.log &
    SSH_PID=$!
    sleep 8
    varurl=$(grep -oE "https://[a-zA-Z0-9.-]+\.serveo\.net" ~/tunnel.log | head -n1)
    if [ -z "$varurl" ]; then
        kill $SSH_PID 2>/dev/null
        return 1
    fi
    TUNNEL_PID=$SSH_PID
    return 0
}

start_cloudflared() {
    if command -v cloudflared >/dev/null 2>&1; then
        cloudflared tunnel --url http://localhost:8080 --logfile ~/tunnel.log > /dev/null 2>&1 &
        CLOUDFLARE_PID=$!
        sleep 8
        varurl=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" ~/tunnel.log | head -n1)
        if [ -z "$varurl" ]; then
            kill $CLOUDFLARE_PID 2>/dev/null
            return 1
        fi
        TUNNEL_PID=$CLOUDFLARE_PID
        return 0
    fi
    return 1
}

start_ngrok() {
    if command -v ngrok >/dev/null 2>&1; then
        ngrok http 8080 --log=stdout > ~/tunnel.log 2>&1 &
        NGROK_PID=$!
        sleep 10
        varurl=$(grep -oE "https://[a-zA-Z0-9]+\.ngrok\.io" ~/tunnel.log | head -n1)
        if [ -z "$varurl" ]; then
            kill $NGROK_PID 2>/dev/null
            return 1
        fi
        TUNNEL_PID=$NGROK_PID
        return 0
    fi
    return 1
}

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
    fi
    return 1
}

# Try each tunnel method
if start_serveo; then
    TUNNEL_TYPE="Serveo"
elif start_cloudflared; then
    TUNNEL_TYPE="Cloudflared"
elif start_ngrok; then
    TUNNEL_TYPE="Ngrok"
elif start_npx; then
    TUNNEL_TYPE="LocalTunnel"
else
    echo "[✗] All tunnel methods failed. Please ensure dependencies are installed."
    exit 1
fi

echo "[✓] Tunnel started using $TUNNEL_TYPE:"
echo "     $varurl"
echo "---------------------------------------------------------------"

# Start simple HTTP server (using Python or BusyBox)
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
    echo "[✗] No web server found (need Python or BusyBox)."
    kill $TUNNEL_PID 2>/dev/null
    exit 1
fi

trap 'echo "Cleaning up..."; kill $TUNNEL_PID $SERVER_PID 2>/dev/null' EXIT

echo "[*] Local server running at http://localhost:8080"
echo "[*] Tunnel URL: $varurl"
echo "[*] Press Ctrl+C to stop."

wait
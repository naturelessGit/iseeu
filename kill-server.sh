#!/bin/bash

echo "[*] Killing Serveo SSH tunnel..."
pkill -f "ssh -o StrictHostKeyChecking=no -R 80:localhost"

echo "[*] Killing Cloudflared..."
pkill -f "cloudflared tunnel"

echo "[*] Killing Python HTTP server..."
pkill -f "python3 -m http.server"

echo "[*] Killing ncat or nc..."
pkill -f "ncat"
pkill -f "nc"
pkill -f "busybox nc"

# Optional: List processes using port 8080
if command -v lsof >/dev/null 2>&1; then
  echo "[*] Ports in use on :8080"
  lsof -i :8080
fi

echo "[*] Checking for leftover busybox processes..."
ps aux | grep '[b]usybox'

echo "[✓] Services killed successfully."
sleep 2

# Restart main script
if [[ -x start.sh ]]; then
  echo "[*] Restarting start.sh..."
  exec ./start.sh
else
  echo "[!] start.sh not found or not executable."
fi
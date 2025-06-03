#!/bin/bash

echo "[*] Killing serveo SSH tunnel..."
pkill -f serveo

echo "[*] Checking for busybox processes..."
ps | grep '[b]usybox'

echo "[*] Killing Python HTTP server..."
pkill -f "python3 -m http.server"

echo "[*] Killing ncat..."
pkill ncat

echo "[*] services killed successfully" && sleep 5
chmod +x start.sh && ./start.sh
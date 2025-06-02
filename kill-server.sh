#!/bin/bash
clear

echo "[*] Stopping active services..."

pkill -f "ssh -R 80:localhost:8080 serveo.net" && echo "[✓] SSH tunnel terminated." || echo "[!] No active SSH tunnel."
pkill -f "busybox httpd -f -p 8080" && echo "[✓] BusyBox server terminated." || echo "[!] No active BusyBox server."
pkill -f "python3 -m http.server 8080" && echo "[✓] Python server terminated." || echo "[!] No active Python server."
pkill -f "ncat -l 8080" && echo "[✓] Ncat server terminated." || echo "[!] No active Ncat server."

echo -e "\n[+] All services stopped successfully."
sleep 2
clear
exit 0

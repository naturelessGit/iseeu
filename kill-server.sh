#!/bin/bash
clear
# Function to kill processes gracefully
kill_servers() {
    # Kill SSH tunnel if running
    if pgrep -f "ssh -R 80:localhost:8080 serveo.net" >/dev/null; then
        pkill -f "ssh -R 80:localhost:8080 serveo.net"
        echo "[✓] SSH tunnel terminated."
    else
        echo "[!] No active SSH tunnel found."
    fi

    # Kill BusyBox httpd if running
    if pgrep -f "busybox httpd -f -p 8080" >/dev/null; then
        pkill -f "busybox httpd -f -p 8080"
        echo "[✓] BusyBox web server terminated."
    else
        echo "[!] No active BusyBox server found."
    fi

    # Kill Python http.server if running
    if pgrep -f "python3 -m http.server 8080" >/dev/null; then
        pkill -f "python3 -m http.server 8080"
        echo "[✓] Python web server terminated."
    else
        echo "[!] No active Python server found."
    fi

    # Kill ncat if running
    if pgrep -f "ncat -l 8080" >/dev/null; then
        pkill -f "ncat -l 8080"
        echo "[✓] Ncat web server terminated."
    else
        echo "[!] No active Ncat server found."
    fi
}

# Execute cleanup
kill_servers

# Confirmation message
echo -e "\n[+] All services stopped successfully."
sleep 2
clear
exit 0

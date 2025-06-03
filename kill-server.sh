#!/bin/bash
clear

# Function to kill processes gracefully
kill_servers() {
    declare -A services=(
        ["SSH tunnel"]="ssh -R 80:localhost:8080 serveo.net"
        ["BusyBox server"]="busybox httpd -f -p 8080"
        ["Python server"]="python3 -m http.server 8080"
        ["Ncat server"]="ncat -l 8080"
pkill ncat
    )

    for name in "${!services[@]}"; do
        pattern="${services[$name]}"
        if pgrep -f "$pattern" > /dev/null; then
            pkill -f "$pattern"
            echo "[✓] $name terminated."
        else
            echo "[!] No active $name found."
        fi
    done
}

# Execute cleanup
kill_servers

# Confirmation
echo -e "\n[+] All services stopped successfully."
sleep 2
clear
exit 0
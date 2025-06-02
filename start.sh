#!/bin/bash

clear
echo "[1] Start I-See-U"
echo "[2] Stop services and restart helper"

read -rp "> " choice

case "$choice" in
  1)
    clear
    chmod +x Iseeu.sh
    sh Iseeu.sh
    ;;
  2)
    clear
    chmod +x kill-server.sh start.sh
    ./kill-server.sh
    ./start.sh
    ;;
  *)
    echo "[!] Invalid option. Try again."
    sleep 2
    exec "$0"
    ;;
esac
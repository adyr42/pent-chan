#!/bin/bash

# ==========================================
# BugHunter – Recon & XSS Shell Automation
# Final Version with Telegram + .env support
# ==========================================
echo "
                       __                   .__                   
 ______   ____   _____/  |_            ____ |  |__ _____    ____  
 \____ \_/ __ \ /    \   __\  ______ _/ ___\|  |  \\__  \  /    \ 
 |  |_> >  ___/|   |  \  |   /_____/ \  \___|   Y  \/ __ \|   |  \
 
 |   __/ \___  >___|  /__|            \___  >___|  (____  /___|  /
 |__|        \/     \/                    \/     \/     \/     \/ 
"

subs_file="subs.txt"
alive_file="subs-active.txt"
xss_file="dalfoxes.txt"
log_file="scan.log"
results_dir="results"
merged_params="merged-params.txt"
mkdir -p "$results_dir"

# === Load .env ===
if [[ -f .env ]]; then
  source .env
else
  echo "[!] File .env tidak ditemukan. Notifikasi Telegram tidak aktif."
fi

# === Kirim Telegram ===
send_telegram() {
  local msg="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      -d text="$msg" > /dev/null
  fi
}

# === Install Semua Tools ===
install_tools() {
  echo "[*] Menginstal tools..." | tee -a "$log_file"
  sudo apt update
  sudo apt install -y subfinder httpx-toolkit paramspider dirsearch sqlmap golang lynx python3 python3-setuptools
  go install github.com/hahwul/dalfox/v2@latest
  sudo cp ~/go/bin/dalfox /usr/bin/
  echo "[✓] Semua tools berhasil diinstal!" | tee -a "$log_file"
  send_telegram "✅ Semua tools berhasil diinstal!"
}

# === Cari Subdomain ===
find_subdomains() {
  read -p "Masukkan domain target: " domain
  subfinder -d "$domain" -silent -o "$subs_file"

  lynx -dump "https://www.google.com/search?q=site:$domain" | \
    grep -Eo "https?://[a-zA-Z0-9._-]+\.$domain" | sed 's@https\?://@@' >> "$subs_file"

  sort -u "$subs_file" -o "$subs_file"
  total=$(wc -l < "$subs_file")
  send_telegram "🔍 Subdomain ditemukan: $total dari $domain"
}

# === Cek Subdomain Aktif ===
test_subdomains() {
  httpx-toolkit -l "$subs_file" -mc 200 -silent -o "$alive_file"
  total=$(wc -l < "$alive_file")
  send_telegram "🌐 Subdomain aktif: $total"
}

# === Scan Direktori ===
dirsearch_scan() {
  while read -r url; do
    echo "[+] Dirsearch scan: $url" | tee -a "$log_file"
    sudo dirsearch -u "$url" -i 200
  done < "$alive_file"
  send_telegram "📂 Dirsearch selesai untuk semua subdomain aktif"
}

# === Paramspider & Gabung ===
find_params() {
  paramspider -l "$alive_file"
  > "$merged_params"
  for f in "$results_dir"/*.txt; do
    [[ -f "$f" ]] && cat "$f" >> "$merged_params"
  done
  sort -u "$merged_params" -o "$merged_params"
  total=$(wc -l < "$merged_params")
  send_telegram "🔢 Parameter URL ditemukan: $total"
}

# === Jalankan Dalfox ===
scan_xss() {
  > "$xss_file"
  dalfox file "$merged_params" -b hahwul.xss.ht >> "$xss_file"
  xss_count=$(grep -c 'POC:' "$xss_file")
  send_telegram "🛡️ XSS ditemukan oleh Dalfox: $xss_count"
}

combine_and_send_results() {
  local final_output="final-report.txt"
  local domain=$(head -n 1 "$subs_file" | cut -d'.' -f2-)  # contoh: www.vulnweb.com → vulnweb.com
  local datetime=$(date '+%Y-%m-%d %H:%M:%S')

  echo "===== 🔐 BugHunter Scan Report =====" > "$final_output"
  echo "Target   : $domain" >> "$final_output"
  echo "Waktu    : $datetime" >> "$final_output"
  echo "======================================" >> "$final_output"
  echo "" >> "$final_output"

  echo "===== 🧪 XSS Report =====" >> "$final_output"
  if [[ -s "$xss_file" ]]; then
    head -n 50 "$xss_file" >> "$final_output"
  else
    echo "(tidak ada hasil dari dalfox)" >> "$final_output"
  fi
  echo "" >> "$final_output"

  echo "===== 📂 Dirsearch Manual (tidak otomatis tersimpan) =====" >> "$final_output"
  echo "Silakan salin output terminal dari dirsearch atau gabungkan log dirsearch-*.txt jika tersedia." >> "$final_output"
  echo "" >> "$final_output"

  echo "===== 🔍 Parameter URLs =====" >> "$final_output"
  if [[ -s "$merged_params" ]]; then
    head -n 50 "$merged_params" >> "$final_output"
  else
    echo "(tidak ada hasil parameter dari paramspider)" >> "$final_output"
  fi

  # Kirim file via Telegram
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
      -F chat_id="$TELEGRAM_CHAT_ID" \
      -F document=@"$final_output" \
      -F caption="📄 Laporan gabungan selesai dikompilasi!"
  else
    echo "[!] Token atau Chat ID Telegram tidak tersedia."
  fi
}


# === All-in-One ===
all_in_one() {
  find_subdomains
  test_subdomains
  dirsearch_scan
  find_params
  scan_xss
  combine_and_send_results
  send_telegram "🎉 ALL-IN-ONE selesai dan laporan sudah dikirim!"
}

# === Menu Utama ===
main_menu() {
  while true; do
    echo ""
    echo "========== BugHunter =========="
    echo "1. Install semua tools"
    echo "2. Cari subdomain"
    echo "3. Tes subdomain aktif"
    echo "4. Scan direktori (dirsearch)"
    echo "5. Cari parameter & XSS"
    echo "6. Gabungkan dan kirim laporan"
    echo "7. ALL IN ONE"
    echo "8. Keluar"
    echo "==============================="
    read -p "Pilih opsi [1-8]: " opsi

    case $opsi in
      1) install_tools ;;
      2) find_subdomains ;;
      3) test_subdomains ;;
      4) dirsearch_scan ;;
      5) find_params; scan_xss ;;
      6) combine_and_send_results ;;
      7) all_in_one ;;
      8) echo "[!] Keluar..."; exit 0 ;;
      *) echo "[!] Pilihan tidak valid." ;;
    esac
  done
}

# Jalankan menu
main_menu

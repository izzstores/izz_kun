#!/bin/bash
# =========================================
# IZZ TUNNELING System Updater
# Quick Fix & Update Services
# =========================================
clear
echo -e "\e[36m========================================\e[0m"
echo -e "\e[1;32m       UPDATING IZZ TUNNELING SYSTEM    \e[0m"
echo -e "\e[36m========================================\e[0m"
sleep 1

REPO="https://raw.githubusercontent.com/izzstores/izz_kun/main/"
domain=$(head -n 1 /etc/xray/domain 2>/dev/null | tr -d '\r\n ' || head -n 1 /root/domain 2>/dev/null | tr -d '\r\n ' || echo "")
[ -z "$domain" ] && domain=$(cat /etc/xray/domain 2>/dev/null | grep -v "^#" | head -n 1 | tr -d '\r\n ')
[ -z "$domain" ] && domain="localhost"

# 1. Update Menu
echo -e "\e[33m[*] Mengunduh paket menu terbaru...\e[0m"
mkdir -p /cache
cd /cache
wget -q -O menu.zip "${REPO}Cdy/menu.zip"
unzip -o menu.zip >/dev/null 2>&1
chmod +x menu/*
mv -f menu/* /usr/local/sbin/
cp -rf /usr/local/sbin/* /usr/bin/ 2>/dev/null || true
cp -rf /usr/local/sbin/* /usr/local/bin/ 2>/dev/null || true
cd /root
rm -rf /cache

# 2. Update WebSocket ePro binary & service (Anti Text File Busy)
echo -e "\e[33m[*] Memperbarui WebSocket ePro...\e[0m"
systemctl stop ws >/dev/null 2>&1 || true
killall -9 ws >/dev/null 2>&1 || true
wget -q -O /usr/bin/ws.new "${REPO}Fls/ws"
if [ -s /usr/bin/ws.new ]; then
    chmod +x /usr/bin/ws.new
    mv -f /usr/bin/ws.new /usr/bin/ws
fi
wget -q -O /usr/bin/tun.conf "${REPO}Cfg/tun.conf"
chmod 644 /usr/bin/tun.conf
wget -q -O /etc/systemd/system/ws.service "${REPO}Fls/ws.service"
chmod 644 /etc/systemd/system/ws.service
systemctl daemon-reload >/dev/null 2>&1
systemctl enable ws >/dev/null 2>&1
systemctl restart ws >/dev/null 2>&1

# 3. Fix Xray Core & Permissions
echo -e "\e[33m[*] Memeriksa integritas Xray Core...\e[0m"
mkdir -p /run/xray /var/log/xray /etc/xray /usr/local/share/xray /usr/local/bin
touch /var/log/xray/access.log /var/log/xray/error.log
chmod 777 /var/log/xray /var/log/xray/*.log
chmod 755 /run/xray /etc/xray

if [ ! -f /usr/local/bin/xray ] || [ ! -s /usr/local/bin/xray ]; then
    wget -q -O /tmp/xray.zip "${REPO}Fls/xray.zip" || wget -q -O /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v25.8.31/Xray-linux-64.zip"
    if [ -f /tmp/xray.zip ]; then
        unzip -o /tmp/xray.zip -d /tmp/xray_ext/ >/dev/null 2>&1
        mv -f /tmp/xray_ext/xray /usr/local/bin/xray 2>/dev/null || true
        mv -f /tmp/xray_ext/*.dat /usr/local/share/xray/ 2>/dev/null || true
        rm -rf /tmp/xray.zip /tmp/xray_ext
    fi
fi
chmod +x /usr/local/bin/xray
ln -sf /usr/local/share/xray/*.dat /usr/local/bin/ 2>/dev/null || true

cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Environment="XRAY_LOCATION_ASSET=/usr/local/share/xray"
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=always
RestartSec=3
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload >/dev/null 2>&1
systemctl enable xray >/dev/null 2>&1
systemctl restart xray >/dev/null 2>&1

# 4. Stop Port Conflicts & Configure NGINX (Zero-HAProxy)
echo -e "\e[33m[*] Memperbarui konfigurasi Nginx (Zero-HAProxy)...\e[0m"
systemctl stop haproxy >/dev/null 2>&1 || true
systemctl disable haproxy >/dev/null 2>&1 || true
systemctl stop apache2 >/dev/null 2>&1 || true
systemctl disable apache2 >/dev/null 2>&1 || true
killall -9 haproxy >/dev/null 2>&1 || true
killall -9 apache2 >/dev/null 2>&1 || true
killall -9 nginx >/dev/null 2>&1 || true

# Purge any conflicting old site configs
rm -f /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* 2>/dev/null || true
rm -f /etc/nginx/conf.d/* 2>/dev/null || true
mkdir -p /var/www/html /var/log/nginx /etc/nginx/conf.d /etc/xray
touch /var/log/nginx/access.log /var/log/nginx/error.log
chmod -R 755 /var/log/nginx

# Ensure SSL certificate exists
if [ ! -s /etc/xray/xray.crt ] || [ ! -s /etc/xray/xray.key ]; then
    echo -e "\e[33m[*] Membuat SSL Certificate fallback...\e[0m"
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=IZZ TUNNELING/OU=VPN/CN=${domain}" \
        -keyout /etc/xray/xray.key -out /etc/xray/xray.crt >/dev/null 2>&1
fi
chmod 644 /etc/xray/xray.crt 2>/dev/null || true
chmod 644 /etc/xray/xray.key 2>/dev/null || true

wget -q -O /etc/nginx/conf.d/xray.conf "${REPO}Cfg/xray.conf"
sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/xray.conf
wget -q -O /etc/nginx/nginx.conf "${REPO}Cfg/nginx.conf"

# Verify Nginx syntax
echo -e "\e[33m[*] Memvalidasi sintaks Nginx...\e[0m"
nginx -t
if [ $? -eq 0 ]; then
    systemctl unmask nginx >/dev/null 2>&1 || true
    systemctl enable nginx >/dev/null 2>&1 || true
    systemctl restart nginx
    if systemctl is-active --quiet nginx; then
        echo -e "\e[32m[✓] Nginx berhasil aktif (ON)!\e[0m"
    else
        echo -e "\e[31m[!] Nginx gagal aktif via systemd, mencoba direct daemon...\e[0m"
        /usr/sbin/nginx -g "daemon on;" 2>/dev/null || true
    fi
else
    echo -e "\e[31m[!] Sintaks Nginx bermasalah, periksa output di atas!\e[0m"
fi

# 5. Fix SSH & Dropbear Authentication, Shells & Home Dirs
echo -e "\e[33m[*] Memperbaiki Otentikasi SSH & Dropbear...\e[0m"
for sh in "/bin/false" "/usr/bin/false" "/usr/sbin/nologin" "/bin/sh" "/bin/bash"; do
    grep -q -x "$sh" /etc/shells 2>/dev/null || echo "$sh" >> /etc/shells
done

wget -q -O /etc/ssh/sshd_config "${REPO}Fls/sshd" 2>/dev/null || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true
systemctl restart dropbear >/dev/null 2>&1 || true

# 6. Setup Auto-Purge Cron & Execute Instant Cleanup
echo -e "\e[33m[*] Menyiapkan jadwal pembersihan otomatis (Cron XP)...\e[0m"
cat >/etc/cron.d/xp_all <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 * * * * root /usr/local/sbin/xp >/dev/null 2>&1
2 0 * * * root /usr/local/sbin/xp >/dev/null 2>&1
END
chmod 644 /etc/cron.d/xp_all
systemctl enable --now cron >/dev/null 2>&1 || true
systemctl restart cron >/dev/null 2>&1 || true

# Run instant purge for all expired accounts across SSH & Xray
echo -e "\e[33m[*] Membersihkan akun yang sudah expired dari sistem & database...\e[0m"
/usr/local/sbin/xp >/dev/null 2>&1 || true

# Auto-repair ONLY ACTIVE (non-expired) SSH accounts in database
echo -e "\e[33m[*] Sinkronisasi akun SSH aktif...\e[0m"
if [ -f /etc/ssh/.ssh.db ]; then
    now_epoch=$(date +%s)
    while read -r line; do
        [[ "$line" != \#ssh\#* ]] && continue
        u=$(echo "$line" | awk '{print $2}' | tr -d '\r\n\t ')
        p=$(echo "$line" | awk '{print $3}' | tr -d '\r\n\t ')
        exp=$(echo "$line" | awk '{print $(NF-2)" "$(NF-1)" "$NF}')
        clean_exp=$(echo "$exp" | sed 's/,//g')
        exp_epoch=$(date -d "$clean_exp" +%s 2>/dev/null)
        if [[ -n "$exp_epoch" && "$exp_epoch" =~ ^[0-9]+$ ]]; then
            sisa=$(( (exp_epoch - now_epoch) / 86400 ))
            if (( sisa > 0 && ${#u} > 0 )); then
                id "$u" >/dev/null 2>&1 || useradd -s /bin/false -m -d "/home/$u" "$u" 2>/dev/null || true
                mkdir -p "/home/$u"
                chown "$u:$u" "/home/$u" 2>/dev/null || true
                chmod 755 "/home/$u" 2>/dev/null || true
                usermod -s /bin/false "$u" 2>/dev/null || true
                usermod -U "$u" 2>/dev/null || true
                if [ -n "$p" ]; then
                    echo "$u:$p" | chpasswd
                fi
                chage -E $(date -d "$clean_exp" +"%Y-%m-%d" 2>/dev/null) -m 0 -M 99999 -W 7 -I -1 "$u" 2>/dev/null || true
                echo -e "  [+] Akun aktif: '$u' ($sisa hari tersisa)"
            fi
        fi
    done < /etc/ssh/.ssh.db
fi

# 7. Fix files-ip -> limit-ip symlink & Version
ln -sf /usr/bin/limit-ip /usr/bin/files-ip 2>/dev/null || true
echo "4.0" > /usr/bin/ver 2>/dev/null || true

# Drop RAM cache
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

echo -e "\e[32m========================================\e[0m"
echo -e "\e[32m[✓] Pembaruan & Pembersihan Sukses Selesai!\e[0m"
echo -e "\e[32m========================================\e[0m"
sleep 2
exec menu

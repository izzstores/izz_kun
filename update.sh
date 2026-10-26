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
for tool in /usr/local/sbin/*; do
    [ -f "$tool" ] && ln -sf "$tool" /usr/bin/ 2>/dev/null || true
    [ -f "$tool" ] && ln -sf "$tool" /usr/local/bin/ 2>/dev/null || true
done
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

# 3. Fix Xray Core & Logs Permissions
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

# 4. Clean HAProxy & Apache Conflicts, Update NGINX
echo -e "\e[33m[*] Memperbarui konfigurasi Nginx (Zero-HAProxy)...\e[0m"
systemctl disable --now haproxy >/dev/null 2>&1 || true
systemctl disable --now apache2 >/dev/null 2>&1 || true
apt remove -y haproxy apache2 >/dev/null 2>&1 || true
killall -9 haproxy >/dev/null 2>&1 || true
killall -9 apache2 >/dev/null 2>&1 || true
rm -rf /etc/haproxy
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default 2>/dev/null || true

mkdir -p /var/www/html /var/log/nginx /etc/nginx/conf.d
touch /var/log/nginx/access.log /var/log/nginx/error.log

# Ensure SSL cert exists
if [ ! -s /etc/xray/xray.crt ] || [ ! -s /etc/xray/xray.key ]; then
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=IZZ TUNNELING/OU=VPN/CN=${domain}" \
        -keyout /etc/xray/xray.key -out /etc/xray/xray.crt >/dev/null 2>&1
fi
chmod 644 /etc/xray/xray.crt 2>/dev/null || true
chmod 600 /etc/xray/xray.key 2>/dev/null || true

wget -q -O /etc/nginx/conf.d/xray.conf "${REPO}Cfg/xray.conf"
sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/xray.conf
wget -q -O /etc/nginx/nginx.conf "${REPO}Cfg/nginx.conf"

# Verify Nginx config syntax before restarting
nginx -t >/dev/null 2>&1
if [ $? -eq 0 ]; then
    killall -9 nginx >/dev/null 2>&1 || true
    systemctl restart nginx >/dev/null 2>&1
else
    echo -e "\e[31m[!] Nginx syntax error detected, restarting with fallback...\e[0m"
    killall -9 nginx >/dev/null 2>&1 || true
    systemctl restart nginx >/dev/null 2>&1
fi

# Ensure xray.service is User=root
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

# 5. Fix SSH & Dropbear Authentication, Shells & Home Dirs
echo -e "\e[33m[*] Memperbaiki Otentikasi SSH & Dropbear...\e[0m"
grep -q -x "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells
grep -q -x "/usr/sbin/nologin" /etc/shells || echo "/usr/sbin/nologin" >> /etc/shells

wget -q -O /etc/ssh/sshd_config "${REPO}Fls/sshd" 2>/dev/null || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true
systemctl restart dropbear >/dev/null 2>&1 || true

# Auto-repair all existing SSH accounts in database
if [ -f /etc/ssh/.ssh.db ]; then
    while read -r line; do
        u=$(echo "$line" | awk '{print $2}')
        p=$(echo "$line" | awk '{print $3}')
        if [ -n "$u" ] && id "$u" >/dev/null 2>&1; then
            mkdir -p "/home/$u"
            chown "$u:$u" "/home/$u" 2>/dev/null || true
            chmod 700 "/home/$u" 2>/dev/null || true
            if [ -n "$p" ]; then
                echo "$u:$p" | chpasswd 2>/dev/null || true
            fi
        fi
    done < /etc/ssh/.ssh.db
fi

# 6. Fix files-ip -> limit-ip symlink & Version
ln -sf /usr/bin/limit-ip /usr/bin/files-ip 2>/dev/null || true
echo "4.0" > /usr/bin/ver 2>/dev/null || true

echo -e "\e[32m[✓] Pembaruan & Perbaikan Servis Sukses Selesai!\e[0m"
sleep 2
exec menu

echo
echo -e "[$(date)] Processed update script..."
sleep 1
apt install wget -y
mkdir -p /cache
cd /cache
wget -q -O menu.zip "https://raw.githubusercontent.com/izzstores/izz_kun/main/Cdy/menu.zip"
unzip menu.zip &>/dev/null
chmod +x menu/*
mv menu/* /usr/local/sbin/
cd
rm -rf /cache

rm -f /etc/haproxy/haproxy.cfg
touch /etc/haproxy/haproxy.cfg
chmod 640 /etc/haproxy/haproxy.cfg

systemctl restart haproxy &>/dev/null

wget -q -O /etc/nginx/conf.d/xray.conf "https://raw.githubusercontent.com/izzstores/izz_kun/main/Cfg/xray.conf"

wget -q -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/izzstores/izz_kun/main/Cfg/nginx.conf"

systemctl restart nginx

# Update SlowDNS & Multiplexer
wget -q -O /usr/local/sbin/m-slowdns "https://raw.githubusercontent.com/izzstores/izz_kun/main/Fls/m-slowdns" && chmod 755 /usr/local/sbin/m-slowdns
wget -q -O /usr/local/sbin/sd "https://raw.githubusercontent.com/izzstores/izz_kun/main/Fls/sd" && chmod 755 /usr/local/sbin/sd
mkdir -p /root/slowdns
wget -q -O /root/slowdns/multiplexer.py "https://raw.githubusercontent.com/izzstores/izz_kun/main/Fls/multiplexer.py" && chmod 700 /root/slowdns/multiplexer.py
wget -q -O /etc/systemd/system/slowdns-mux.service "https://raw.githubusercontent.com/izzstores/izz_kun/main/Fls/slowdns-mux.service"
systemctl daemon-reload
systemctl enable --now slowdns-mux.service &>/dev/null

sleep 2
echo
echo -e "[$(date)] Update script Success"
sleep 0.5
echo -e "[$(date)] Back to menu in 3 seconds"
sleep 3
menu

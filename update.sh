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
systemctl restart nginx

sleep 2
echo
echo -e "[$(date)] Update script Success"
sleep 0.5
echo -e "[$(date)] Back to menu in 3 seconds"
sleep 3
menu

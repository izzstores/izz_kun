
# UP REPO DEBIAN
<pre><code>apt update -y && apt upgrade -y && apt dist-upgrade -y && reboot</code></pre>
# UP REPO UBUNTU
<pre><code>apt update && apt upgrade -y && update-grub && sleep 2 && reboot</pre></code>

### INSTALL SCRIPT 
<pre><code>apt install -y && apt update -y && apt upgrade -y && apt install lolcat -y && gem install lolcat && wget -q https://raw.githubusercontent.com/izzstores/izz_kun/main/main.sh && chmod +x main.sh && ./main.sh
</code></pre>

### UPDATE SCRIPT
<pre><code>wget -q https://raw.githubusercontent.com/izzstores/izz_kun/main/update.sh && chmod +x update.sh && ./update.sh</code></pre>

### INSTALL SlowDNS
SlowDNS memakai domain milik sendiri yang sudah diarahkan ke IP VPS. Domain random/legacy tidak digunakan lagi.

```sh
wget -q -O /root/slowdns/slowdns https://raw.githubusercontent.com/izzstores/izz_kun/main/Fls/slowdns
wget -q -O /root/slowdns/install.sh https://raw.githubusercontent.com/izzstores/izz_kun/main/Fls/slowdns-install.sh
wget -q -O /usr/local/sbin/sd https://raw.githubusercontent.com/izzstores/izz_kun/main/Fls/sd
chmod 700 /root/slowdns /root/slowdns/slowdns /root/slowdns/install.sh
chmod 755 /usr/local/sbin/sd
bash /root/slowdns/install.sh install
```

#!/usr/bin/env bash

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

header(){
clear
echo -e "${CYAN}"
echo "======================================"
echo "   TunnelPilot L2TP/IPsec FINAL 3.7"
echo "======================================"
echo -e "${NC}"
}

# ===============================
# 🚀 Speed Install Mode
# ===============================
speed_install(){

echo -e "${GREEN}🔥 Speed Install Mode Activated...${NC}"

export DEBIAN_FRONTEND=noninteractive

echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries
echo 'Acquire::http::Timeout "10";' >> /etc/apt/apt.conf.d/80-retries
echo 'Acquire::https::Timeout "10";' >> /etc/apt/apt.conf.d/80-retries
echo 'APT::Acquire::Retries "3";' >> /etc/apt/apt.conf.d/80parallel
echo 'Acquire::Queue-Mode "access";' >> /etc/apt/apt.conf.d/80parallel

sudo apt-get install -y strongswan xl2tpd ppp iptables curl

echo -e "${GREEN}✅ Speed Install Completed${NC}"

}

# ===============================
# 🔹 Setup KHAREJ Server
# ===============================
setup_kharej(){

read -p "Enter PSK Key: " PSK
read -p "Enter Username: " USER
read -p "Enter Password: " PASS
read -p "Enter Local IP (example 172.20.0.1): " LOCALIP
read -p "Enter IP Range (example 172.20.0.10-172.20.0.100): " IPRANGE

cat > /etc/ipsec.conf <<EOF
config setup
uniqueids=no

conn L2TP-PSK
keyexchange=ikev1
authby=secret
ike=aes256-sha1-modp1024!
esp=aes256-sha1!
auto=add
type=transport
left=%any
leftprotoport=17/1701
right=%any
rightprotoport=17/%any
forceencaps=yes
EOF

cat > /etc/ipsec.secrets <<EOF
: PSK "$PSK"
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

[lns default]
ip range = $IPRANGE
local ip = $LOCALIP
require chap = yes
name = TunnelPilot
pppoptfile = /etc/ppp/options.xl2tpd
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
require-mschap-v2
ms-dns 1.1.1.1
ms-dns 8.8.8.8
mtu 1400
mru 1400
EOF

echo "$USER * $PASS *" >> /etc/ppp/chap-secrets

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -j MASQUERADE

systemctl restart strongswan-starter 2>/dev/null || systemctl restart strongswan
systemctl restart xl2tpd

echo -e "${GREEN}🔥 KHAREJ SERVER READY${NC}"

}

# ===============================
# 🔹 Setup IRAN Server
# ===============================
setup_iran(){

read -p "Enter KHAREJ Server IP: " SERVERIP
read -p "Enter PSK Key: " PSK
read -p "Enter Username: " USER
read -p "Enter Password: " PASS

cat > /etc/ipsec.conf <<EOF
config setup
uniqueids=no

conn tunnel
keyexchange=ikev1
authby=secret
ike=aes256-sha1-modp1024!
esp=aes256-sha1!
auto=start
type=transport
left=%defaultroute
leftprotoport=17/1701
right=$SERVERIP
rightprotoport=17/1701
forceencaps=yes
EOF

cat > /etc/ipsec.secrets <<EOF
: PSK "$PSK"
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac tunnel]
lns = $SERVERIP
pppoptfile = /etc/ppp/options.l2tpd
EOF

cat > /etc/ppp/options.l2tpd <<EOF
name $USER
password $PASS
mtu 1400
mru 1400
noauth
EOF

ipsec restart
systemctl restart xl2tpd
ipsec up tunnel
sleep 2
echo "c tunnel" > /var/run/xl2tpd/l2tp-control

echo -e "${GREEN}🔥 IRAN CLIENT CONNECTED${NC}"

}

# ===============================
# 🔎 Check Status
# ===============================
check_status(){

echo -e "${YELLOW}Checking Tunnel Status...${NC}"

ipsec status
systemctl status xl2tpd --no-pager

ip a | grep ppp0 && echo -e "${GREEN}PPP Interface UP${NC}" || echo -e "${RED}PPP DOWN${NC}"

}

# ===============================
# ⚙️ Manage Tunnel
# ===============================
manage_tunnel(){

echo "1) Start"
echo "2) Stop"
echo "3) Restart"

read -p "Select: " M

case $M in
1)
ipsec up tunnel
echo "c tunnel" > /var/run/xl2tpd/l2tp-control
;;
2)
ipsec down tunnel
;;
3)
ipsec restart
systemctl restart xl2tpd
;;
esac

}

# ===============================
# MENU
# ===============================
menu(){

header
echo "1) 🔹 Speed Install"
echo "2) 🔹 Setup KHAREJ"
echo "3) 🔹 Setup IRAN"
echo "4) 🔎 Check Tunnel Status"
echo "5) ⚙️ Manage Tunnel"
echo "0) Exit"

read -p "Select: " CH

case $CH in
1) speed_install ;;
2) setup_kharej ;;
3) setup_iran ;;
4) check_status ;;
5) manage_tunnel ;;
0) exit ;;
esac

read -p "Press Enter..."
menu
}

menu

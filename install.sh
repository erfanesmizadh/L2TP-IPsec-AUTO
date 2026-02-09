#!/usr/bin/env bash

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

header(){
clear
echo -e "${CYAN}"
echo "======================================"
echo "   TunnelPilot L2TP/IPsec FINAL"
echo "======================================"
echo -e "${NC}"
}

install_requirements(){

echo -e "${GREEN}Installing packages...${NC}"

apt update -y
apt install -y strongswan xl2tpd ppp iptables

}

setup_kharej(){

header

read -p "Enter PSK Key: " PSK
read -p "Enter Username: " USER
read -p "Enter Password: " PASS

echo ""
echo "Network Configuration:"
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
refuse pap = yes
require authentication = yes
name = TunnelPilot
pppoptfile = /etc/ppp/options.xl2tpd
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
require-mschap-v2
ms-dns 1.1.1.1
ms-dns 8.8.8.8
asyncmap 0
auth
mtu 1400
mru 1400
lock
hide-password
EOF

echo "$USER * $PASS *" >> /etc/ppp/chap-secrets

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -j MASQUERADE

systemctl restart strongswan-starter 2>/dev/null || systemctl restart strongswan
systemctl restart xl2tpd

systemctl enable strongswan-starter 2>/dev/null || systemctl enable strongswan
systemctl enable xl2tpd

echo -e "${GREEN}🔥 KHAREJ SERVER READY${NC}"

}

setup_iran(){

header

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

systemctl restart strongswan-starter 2>/dev/null || systemctl restart strongswan
systemctl restart xl2tpd

ipsec restart
ipsec up tunnel

sleep 2
echo "c tunnel" > /var/run/xl2tpd/l2tp-control

echo -e "${GREEN}🔥 IRAN CLIENT CONNECTED${NC}"

}

menu(){

header

echo "1) Install Requirements"
echo "2) Setup KHAREJ Server"
echo "3) Setup IRAN Server"
echo "0) Exit"

read -p "Select: " CH

case $CH in

1) install_requirements ;;
2) setup_kharej ;;
3) setup_iran ;;
0) exit ;;

esac

read -p "Press Enter..."
menu

}

menu

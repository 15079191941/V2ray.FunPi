#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#check Root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

#install Needed Packages
apt-get update -y
apt-get install wget curl socat git python3 python3-setuptools python3-dev python3-pip openssl libssl-dev ca-certificates supervisor -y
pip3 install -r requirements.txt

#enable rc.local
cat <<EOF >/etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
exit 0
EOF
chmod +x /etc/rc.local
systemctl start rc-local
systemctl status rc-local

#install V2ray
# curl -L -s https://install.direct/go.sh | bash
bash update_v2ray.sh v4.27.0

mkdir -p /etc/v2ray/
touch /etc/v2ray/config.json
mkdir -p /var/log/v2ray/
cat>>/etc/supervisor/supervisord.conf<<EOF
Description=V2Ray Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Environment=V2RAY_LOCATION_ASSET=/usr/local/share/v2ray/
ExecStart=/usr/local/bin/v2ray -config /etc/v2ray/config.json
LimitNPROC=500
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

#start v2ray services
systemctl start v2ray.service

#generate Default Configurations
chmod +x /usr/local/V2ray.Fun/script/start.sh

#configure Supervisor
mkdir /etc/supervisor
mkdir /etc/supervisor/conf.d
echo_supervisord_conf > /etc/supervisor/supervisord.conf
cat>>/etc/supervisor/supervisord.conf<<EOF
[include]
files = /etc/supervisor/conf.d/*.ini
EOF
touch /etc/supervisor/conf.d/v2ray.fun.ini
cat>>/etc/supervisor/conf.d/v2ray.fun.ini<<EOF
[program:v2ray.fun]
command=/usr/local/V2ray.Fun/script/start.sh run
stdout_logfile=/var/log/v2ray.fun
autostart=true
autorestart=true
startsecs=5
priority=1
stopasgroup=true
killasgroup=true
EOF

chmod 644 /etc/v2ray/config.json
supervisord -c /etc/supervisor/supervisord.conf
echo "supervisord -c /etc/supervisor/supervisord.conf">>/etc/rc.local
chmod +x /etc/rc.local

echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf && sysctl -p
cat>>/etc/systemd/system/v2ray_iptable.service<<EOF
[Unit]
Description=Tproxy rule
After=network-online.target
Wants=network-online.target

[Service]

Type=oneshot
ExecStart=/bin/bash /usr/local/V2ray.Fun/script/config_iptable.sh

[Install]
WantedBy=multi-user.target
EOF

echo "install success"
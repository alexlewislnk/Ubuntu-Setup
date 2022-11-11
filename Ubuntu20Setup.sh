#!/bin/bash
#
# After deploying a new Ubuntu Linux server on Digital Ocean or Linode, there
# are a few customization steps I take to improve usability and security of the
# server. This script is intended for a new install of Ubuntu Linux 20.04 LTS.
#
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG=/root/Ubuntu20Setup.log
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
CYAN="$(tput setaf 6)"
NORMAL="$(tput sgr0)"

function DisplayInfo { 
	printf "${CYAN}$INFO${NORMAL}\\n"
	printf "\\n$INFO\\n" >>$LOG
}

> $LOG
INFO="New Ubuntu Server Setup started at $(date)" ; DisplayInfo

INFO="Configure Hostname" ; DisplayInfo
printf "${YELLOW}Please enter a fully qualified hostname (e.g.: host.example.com): ${NORMAL}"
read -r line

INFO="Setting hostname to $line" ; DisplayInfo
hostnamectl set-hostname $line >>$LOG 2>&1
shortname=$(echo "$line" | cut -d"." -f1)
defaultdev=$(ip ro ls|grep default|awk '{print $5}')
primaryaddr=$(ip -f inet addr show dev "$defaultdev" | grep 'inet ' | awk '{print $2}' | cut -d"/" -f1 | cut -f1)
INFO="Primary IPv4 Address identified as $primaryaddr" ; DisplayInfo

INFO="Rebuilding hosts file" ; DisplayInfo
mv /etc/hosts /etc/hosts.old
printf "%s\\t%s\\n" "127.0.0.1" "localhost" > /etc/hosts
printf "%s\\t%s\\t%s\\n" "$primaryaddr" "$line" "$shortname" >> /etc/hosts
cat /etc/hosts >>$LOG 2>&1

INFO="Update Package Repository" ; DisplayInfo
export DEBIAN_FRONTEND=noninteractive
apt update >>$LOG 2>&1

INFO="Install Strong Entropy" ; DisplayInfo
apt -y install haveged pollinate >>$LOG 2>&1
(crontab -l 2>> $LOG ; echo "@reboot sleep 60 ; /usr/bin/pollinate -r" )| crontab - >>$LOG 2>&1

INFO="SSH Server Hardening" ; DisplayInfo
cp /etc/ssh/sshd_config /etc/ssh/backup.sshd_config
cp /etc/ssh/moduli /etc/ssh/backup.moduli
sed -i '/X11Forwarding/c\X11Forwarding no' /etc/ssh/sshd_config >>$LOG 2>&1
sed -i 's/^#HostKey \/etc\/ssh\/ssh_host_\(rsa\|ed25519\)_key$/\HostKey \/etc\/ssh\/ssh_host_\1_key/g' /etc/ssh/sshd_config >>$LOG 2>&1
sed -i 's/^HostKey \/etc\/ssh\/ssh_host_\(dsa\|ecdsa\)_key$/\#HostKey \/etc\/ssh\/ssh_host_\1_key/g' /etc/ssh/sshd_config >>$LOG 2>&1
echo -e "\n# Restrict key exchange, cipher, and MAC algorithms\nKexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256\nCiphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr\nMACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com\nHostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com" > /etc/ssh/sshd_config.d/ssh-audit_hardening.conf
awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
mv /etc/ssh/moduli.safe /etc/ssh/moduli
rm /etc/ssh/ssh_host_* >>$LOG 2>&1
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" >>$LOG 2>&1
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" >>$LOG 2>&1
service ssh restart >>$LOG 2>&1
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" <<<y >>$LOG 2>&1
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" <<<y >>$LOG 2>&1

INFO="Install Useful Linux Packages" ; DisplayInfo
apt -y install apport apt-transport-https aptitude at build-essential byobu command-not-found curl dnsutils ethtool git htop man ntpdate patch psmisc screen software-properties-common sosreport update-motd update-notifier-common vim zip unzip >>$LOG 2>&1

INFO="Create Linux Update Scripts" ; DisplayInfo
cat > /usr/local/bin/linux-update << EOF
export DEBIAN_FRONTEND=noninteractive
apt-get -y autoremove --purge
sync
apt-get clean
apt-get autoclean
apt update
apt -y full-upgrade
sync
update-grub
echo "Press Enter to reboot or Ctrl-C to abort..."
read aa
sync
reboot
EOF
cat > /usr/local/bin/linux-cleanup << EOF
export DEBIAN_FRONTEND=noninteractive
apt-get -y autoremove --purge
sync
update-grub
EOF
chmod +rx /usr/local/bin/linux-update /usr/local/bin/linux-cleanup

INFO="Harden IPv4 Network" ; DisplayInfo
cat > /etc/sysctl.conf <<EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
EOF

INFO="Disable IPv6" ; DisplayInfo
cat >> /etc/sysctl.conf <<EOF
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

INFO="Restrict Root Login to Console" ; DisplayInfo
cp /etc/securetty /etc/securetty.old
cat > /etc/securetty <<EOF
console
tty1
tty2
tty3
tty4
tty5
tty6
EOF

INFO="Configure Time(NTP) Services" ; DisplayInfo
ln -fs /usr/share/zoneinfo/US/Central /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata >>$LOG 2>&1
sed -i '/^#NTP=/c\NTP=time.google.com' /etc/systemd/timesyncd.conf >>$LOG 2>&1
systemctl restart systemd-timesyncd >>$LOG 2>&1
ntpdate -u time.google.com >>$LOG 2>&1

INFO="Schedule Journal Log Cleanup" ; DisplayInfo
(crontab -l 2>> $LOG ; echo "@daily journalctl --vacuum-time=30d --vacuum-size=1G" )| crontab - >>$LOG 2>&1

INFO="Configure Unattended Security Updates" ; DisplayInfo
apt -y install unattended-upgrades >>$LOG 2>&1
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades >>$LOG 2>&1
cat > /etc/apt/apt.conf.d/10periodic <<EOF
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "1";
EOF
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
"\${distro_id}:\${distro_codename}";
"\${distro_id}:\${distro_codename}-security";
"\${distro_id}ESM:\${distro_codename}";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
rm -rf /etc/systemd/system/apt-daily.timer* >>$LOG 2>&1
cat > /etc/systemd/system/apt-daily.timer <<EOF
[Unit]
Description=Daily apt download activities
[Timer]
OnCalendar=*-*-* 6,18:00
RandomizedDelaySec=6h
Persistent=true
[Install]
WantedBy=timers.target
EOF
rm -rf /etc/systemd/system/apt-daily-upgrade.timer* >>$LOG 2>&1
cat > /etc/systemd/system/apt-daily-upgrade.timer <<EOF
Description=Daily apt upgrade and clean activities
After=apt-daily.timer
[Timer]
OnCalendar=*-*-* 0:25
RandomizedDelaySec=30m
Persistent=true
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload >>$LOG 2>&1

INFO="Install Linux Updates" ; DisplayInfo
apt -y full-upgrade >>$LOG 2>&1

INFO="New Ubuntu Server Setup completed at $(date)" ; DisplayInfo
INFO="${YELLOW}After checking the log file ${RED}$LOG${YELLOW} for any errors, you will need to reboot the system." ; DisplayInfo
# End

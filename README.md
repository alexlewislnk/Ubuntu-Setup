This script is used on a new install of Ubuntu 22.04 LTS or 20.04 LTS to complete the setup and basic security of the OS. 
This should only be run on a freshly provisioned server. Can also be used for virtual and VPS servers.

## How to Use
(Login as root)

Download the script
```
wget -O /tmp/Ubuntu20Setup.sh https://raw.githubusercontent.com/alexlewislnk/Ubuntu-Setup/main/Ubuntu20Setup.sh
chmod +rx /tmp/Ubuntu20Setup.sh
```

Run the Script
```
/tmp/Ubuntu20Setup.sh
```

## What does the script do?
- Prompt for and properly configure the FQDN hostname of the server
- Install strong entropy packages for less predictable random number generation and stronger cryptographic keys
- Harden the SSH server and create new keys
- Install basic set of linux packages commonly used on servers
- Harden IPv4 kernel settings to resist common attacks
- Configure NTP server to sync date/time to reliable time server
- Configure nightly unattended install of security patches


## Optional Steps

**Swap File**

If a swap partition was not created by the deployment, create one based on the amount of RAM installed.

|Installed RAM (GB)|Swap File (GB)|
|---|---|
|2 or less|1|
|3 – 6|2|
|7 – 12|3|
|13 – 20|4|
 
```
phymem="$(free -g|awk '/^Mem:/{print $2}')"
swapsize="1G"
if   [[ $phymem -gt 12 ]];  then swapsize="4G"
elif [[ $phymem -gt 6 ]];   then swapsize="3G"
elif [[ $phymem -gt 2 ]];   then swapsize="2G"
fi
fallocate -l $swapsize /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Swap File on Azure**
```
cp /etc/waagent.conf /etc/waagent.conf.save
sed -i '/ResourceDisk.Format/c\ResourceDisk.Format=y' /etc/waagent.conf
sed -i '/ResourceDisk.EnableSwap/c\ResourceDisk.EnableSwap=y' /etc/waagent.conf
sed -i '/ResourceDisk.SwapSizeMB/c\ResourceDisk.SwapSizeMB=4096' /etc/waagent.conf
service walinuxagent restart
```

**LTS Enablement Stack for latest kernel updates**
```
source /etc/lsb-release
export DEBIAN_FRONTEND=noninteractive
systemd-detect-virt -vq
if [[ $? = 0 ]]; then 
	apt -y install --install-recommends linux-virtual-hwe-$DISTRIB_RELEASE
	apt -y remove linux-generic-hwe-$DISTRIB_RELEASE
else
	apt -y install --install-recommends linux-generic-hwe-$DISTRIB_RELEASE
	apt -y remove linux-virtual-hwe-$DISTRIB_RELEASE
fi
```

Reboot and reconnect as root user
```
reboot
```

Remove old kernel packages and dependencies
```
export DEBIAN_FRONTEND=noninteractive
apt -y autoremove ; apt -y purge linux-generic linux-headers-generic linux-image-generic linux-virtual linux-headers-virtual linux-image-virtual ; apt -y autoremove
```

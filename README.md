This script is used on a new install of Ubuntu 20.04 LTS to complete the setup and basic security of the OS. 
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

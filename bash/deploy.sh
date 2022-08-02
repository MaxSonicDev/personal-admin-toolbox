#!/bin/bash
echo "--- Deploy Debian / Ubuntu Linux Server ---"

if (( $EUID != 0 )); then
    echo "You must be root to run this script."
    exit 1
fi

read -p "Whould you like to install and configure your new server ? (y/n) " REPLY
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
    exit 0
fi

# Config : 

if [ -f ./config.txt ]; then
    source config.txt
else 
    echo "Config file not found."
    admin_username=admdeb01
    snmp_username=snmpdeb01
    location=CHANGEME
    contact=CHANGEME
fi 

echo "---------------------------"
echo "🚀 - Update & install basic package"
echo "---------------------------"

apt update >/dev/null 2>&1
apt upgrade -y >/dev/null 2>&1
apt install -y vim htop sudo curl wget git net-tools ufw fail2ban openssh-server snmp snmpd libsnmp-dev molly-guard >/dev/null 2>&1

echo "---------------------------"
echo "🧱 - Configure Firewall (UFW)"
echo "---------------------------"

sudo ufw allow ssh
sudo ufw logging on
sudo ufw enable

echo "---------------------------"
echo "👤 - Add Admin Service user"
echo "---------------------------"

if (id -u "$admin_username" >/dev/null 2>&1); then
    echo "admin user already exists"
else
    sudo useradd $admin_username
    sudo usermod -aG sudo $admin_username
    sudo mkdir /home/$admin_username
    sudo chown $admin_username: -R /home/$admin_username
    sudo chmod 700 -R /home/$admin_username
    password=$( tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n 1 ) # generate random password
    read -p "Do you want to change $admin_username's password (For rescue only | SSH Auth disable) ? (y/n) " REPLY
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        passwd $admin_username
    fi

    echo "$admin_username ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo
    echo "Disable root password"
    sudo passwd -l root
fi

echo "---------------------------"
echo "🔒 - Generate SSH Key for admin user"
echo "---------------------------"
if [ -f /home/$admin_username/.ssh/id_ed25519 ]; then
    echo "SSH key already exists"
else
    sudo -u $admin_username ssh-keygen -t ed25519 -f /home/$admin_username/.ssh/id_ed25519 -N ""
fi


echo "---------------------------"
echo "🕵️ - Configure fail2ban"
echo "---------------------------"

cat <<EOF | sudo tee /etc/fail2ban/jail.d/ssh.conf
[ssh]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

echo "---------------------------"
echo "🔑 - add Github SSH key"
echo "---------------------------"

read -p "Enter your Github username: " github_username
sudo -u $admin_username curl https://github.com/$github_username.keys > /home/$admin_username/.ssh/authorized_keys

echo "---------------------------"
echo "🔧 - Configure SSH"
echo "---------------------------"

# Make a password authentication disable
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
# Make a root login disable
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config

echo "---------------------------"
echo "🧑‍🤝‍🧑 - Generate SNMPv3 community"
echo "---------------------------"
sudo systemctl stop snmpd
sudo mkdir /snmp
AuthSNMP=$( tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n 1 ) # generate random Password
CryptoSNMP=$( tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n 1 ) # generate random Password
sudo net-snmp-create-v3-user -ro -A $AuthSNMP -X $CryptoSNMP -a SHA-512 -x AES $snmp_username
# Put LibreNMS SNMPd configuration
sudo curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
sudo chmod +x /usr/bin/distro
cat <<EOF | sudo tee /etc/snmp/snmpd.conf
agentAddress udp:161,udp6:[::]:161
view all    included  .1                               80
sysLocation $location
sysContact    $contact
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/local/bin/distro

rouser $snmp_username
dontLogTCPWrappersConnects true
EOF

sudo systemctl start snmpd

echo "---------------------------"
echo "✨ - Final step"
echo "---------------------------"

ip=$( hostname -b )
echo -e "SSH control : ssh $admin_username@$ip
Password : $password (only for rescue on tty console)
SNMPv3 username : $snmp_username
SNMPv3 Auth Algorithm : SHA-512
SNMPv3 Auth password : $AuthSNMP
SNMPv3 Crypto Algorithm : AES
SNMPv3 Crypto Password : $CryptoSNMP
"
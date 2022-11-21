#!/bin/bash

echo "---------------------------"
echo "
Welcome to the OpenStack Target Machine Installation script
!!! Warning !!! For RHEL/CentOS/Rocky Linux Only
Use in Tmux or screen pls (Network handling)       
"
echo "---------------------------"

read -p "Whould you like to install and configure your new server ? (y/n) " REPLY
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
    exit 0
fi


if (( $EUID != 0 )); then
    echo "You must be root to run this script."
    exit 1
fi

echo "---------------------------"
echo "🚀 - Update & install basic package"
echo "---------------------------"

dnf update -y >/dev/null 2>&1
dnf install iputils lsof openssh-server sudo tcpdump python3 >/dev/null 2>&1

echo "---------------------------"
echo "🚀 - Disable SELinux"
echo "---------------------------"

sed '%s/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
echo "kernel.printk='4 1 7 4'" >> /etc/sysctl.conf

echo "---------------------------"
echo "🚀 - Download public ssh key of deployment machine"
echo "---------------------------"

echo "" >> /root/.ssh/authorized_keys

read -p "This is a node server ? (y/n)" REPLY
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Nn]$ ]]
then
    lsblk -d -n -oNAME,SIZE | awk -F'/' 'NR>1{print "\047/dev/"$NF}' | sort | uniq 
    echo "---------------------------"
    echo "🚀 - Create a dedicated LVM cinder volume"
    echo "---------------------------"

    read -p "Enter device path : (without \' of course)  " device_path 
    pvcreate --metadatasize 2048 $device_path
    vgcreate cinder-volumes $device_path
fi

echo "---------------------------"
echo "🚀 - Network Creation"
echo "---------------------------"

read -p "Enter physicial network device ID for management" net_id
read -p "Enter physicial network device ID for VxLan" net_id2
read -p "Enter physicial network device ID for Storage" net_id3
read -p "Enter ip address for management" ip_id
read -p "Enter Gateway for management (X.X.X.X/XX format)" gw_id
read -p "Enter dns address for management (if empty use Quad9 DNS & CloudFlare DNS)" ip_id
read -p "Enter ip address for VxLan" ip_id2
read -p "If target is a compute node, enter ip address for storage (optionnal)" ip_id3 

# Create line for br-storage
if [[ $REPLY =~ ^[Nn]$ ]]
then
    result_storage = "address" + $ip_id3

fi 

# Condition to put by default Quad9 and CloudFlare DNS

# Remove old Network Interface file
rm /etc/network/interface

# Create /etc/network/interface file for different interface
cat <<EOF | sudo tee /etc/network/interface
auto $net_id
iface $net_id inet manual

auto $net_id2
iface $net_id2 inet manual

auto br-mgmt
iface br-mgmt inet static
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports $net_id
    address $ip_id
    gateway $gw_id
    dns-nameservers 9.9.9.9

auto br-vxlan
iface br-vxlan inet static
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports $net_id2
    address $ip_id2

auto br-storage
iface br-storage inet manual
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports $net_id3
    $result_storage


EOF

# disable old network interface and up the new
ifdown $net_id && ifdown $net_id2 && ifdown $net_id3
ifup br-mgmt && ifup br-vxlan && ifup br-storage
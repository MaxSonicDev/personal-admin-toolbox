#!/bin/bash

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

read -p "Enter physicial network device ID" net_id
rm /etc/network/interface
cat <<EOF | sudo tee /etc/network/interface




EOF
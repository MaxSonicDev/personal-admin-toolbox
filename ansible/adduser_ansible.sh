#!/bin/bash

# If user is not root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if user exists
username=ansi
githubusername=maxsonicdev

if id -u $username >/dev/null 2>&1; then
  echo "User $username already exists"
  exit 1
fi

useradd $username
# get github public ssh keys and add to user
mkdir -p /home/$username/.ssh
chmod 700 /home/$username/.ssh
curl -o /home/$username/.ssh/authorized_keys https://github.com/$githubusername.keys
chmod 600 /home/$username/.ssh/authorized_keys
echo "$username ALL=(ALL) NOPASSWD: ALL" | sudo EDITOR='tee -a' visudo
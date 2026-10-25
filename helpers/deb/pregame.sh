#!/bin/bash
# usage: ./helpers/deb/pregame.sh <user> <hostname>
# Prints out the commands to add user
# Should work on any Debian based OS, like Ubuntu

# // Add the main user
usr="${1}"
sudo adduser "$usr"
sudo usermod -aG sudo,adm,dialout "$usr"

# // Update default hostname
hname="${2}"
sudo hostnamectl set-hostname "$hname"
sudo sed -i "s/starfive/${hname}/g" /etc/hosts

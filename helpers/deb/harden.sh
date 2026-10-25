#!/bin/bash
# // Remove the default user
sudo pkill -u user
sudo deluser --remove-home user
sudo rm -f /etc/sudoers.d/user

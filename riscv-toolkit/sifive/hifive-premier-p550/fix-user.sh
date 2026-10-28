#!/bin/bash
# // Remove the default P550 user
sudo pkill -u ubuntu
sudo deluser --remove-home ubuntu
sudo rm -f /etc/sudoers.d/ubuntu

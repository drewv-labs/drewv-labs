#!/bin/bash
# // Remove the default VisionFive 2 user
sudo pkill -u user
sudo deluser --remove-home user
sudo rm -f /etc/sudoers.d/user

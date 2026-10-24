#!/bin/zsh
# Deploy the forge to targeted VF2-Hailo8 Engine node.
scp ./vf2-hailo8-kit/forge/*.sh "${1}:"

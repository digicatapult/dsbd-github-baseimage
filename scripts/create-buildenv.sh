#!/bin/bash
set -euo pipefail

sudo su
cd /home/cheri/cheri/cheribuild
runuser -u cheri -- /home/cheri/cheri/cheribuild/cheribuild.py --build qemu disk-image-morello-purecap -d --force --disk-image/rootfs-type zfs

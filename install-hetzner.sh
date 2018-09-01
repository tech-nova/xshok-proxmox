#!/bin/bash
################################################################################
# This is property of eXtremeSHOK.com
# You are free to use, modify and distribute, however you may not remove this notice.
# Copyright (c) Adrian Jon Kriel :: admin@extremeshok.com
################################################################################
#
# Script updates can be found at: https://github.com/extremeshok/xshok-proxmox
#
# hetzner installation script for Proxmox
#
# License: BSD (Berkeley Software Distribution)
#
##############################################################################
#
# Assumptions:
# Run this script from the hetzner rescue system
# Operating system=Linux, Architecture=64 bit, Public key=*optional*
#
# Assumes 2 or 4 identical disks at /dev/sda and /dev/sdb,sdc,sdd,sde,sdf it ignores any extra disks which are not identical
# Will make sure the raid 1 use sda and the next identical sized disk, eg. sdc if sdb is not the same siza as sda
# software raid 1 (mirror) will be setup as well as LVM and will automatically detect and set the swap size
# If 4 identical disks are detected (sda,sdb,sdc,sdd) raid 10 will be used. (mirror and striped)
#
# SWAP partition size is adjusted according to available drive space
#
################################################################################
#
#   ALL CONFIGURATION OPTIONS ARE LOCATED BELOW THIS MESSAGE
#
################################################################################

#set size of swap file or leave blank for autoconfig, USE NUMBER ONLY, will be in gbytes
MY_SWAP=""
#comment out to disable LVM and use a very simple partition setup of / and swap
USE_LVM="TRUE"

################################################################################

installimage_bin="/root/.oldroot/nfs/install/installimage"

MY_HOSTNAME="$1"
if [ "$MY_HOSTNAME" == "" ]; then
  echo "Please set a hostname"
  echo "$0 host.name"
  exit 1
fi

# Detect discs for software raid and ensure sda and sd? are the identical size
# autoselects the second drive to raid with sda
# sda is always used, as sda is generally the primary boot disk
# disables raid if a suitable second disk is not found
if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdb$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_SLAVE=",sdb"
  MY_RAID_ENABLE="yes"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdc$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_SLAVE=",sdc"
  MY_RAID_ENABLE="yes"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdd$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_SLAVE=",sdd"
  MY_RAID_ENABLE="yes"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sde$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_SLAVE=",sde"
  MY_RAID_ENABLE="yes"
elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdf$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]]; then
  MY_RAID_SLAVE=",sdf"
  MY_RAID_ENABLE="yes"
else
  MY_RAID_SLAVE=""
  MY_RAID_ENABLE="no"
fi

#test for possible raid10, using 4 devices of equal size
if [ "$MY_RAID_ENABLE" == "yes" ]; then
  if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdb$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]] && [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdc$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]] && [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -eq $(awk '/sdd$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) ]] ; then
    MY_RAID_LEVEL="10"
  else
    MY_RAID_LEVEL="1"
  fi
fi




# check for ram size
#if [[ $(( $(vmstat -s | grep -i "total memory" | xargs | cut -d" " -f 1) / 1024 / 1000)) -le "64" ]] ; then

# HDD more than 400gb = 64GB swap
# HDD more than 160gb = 32GB swap
# HDD less than 160gb = 16GB swap
if [ "$MY_SWAP" == "" ]; then
  echo "Detecting and setting optimal swap partition size"
  if [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "400" ]] ; then
    MY_SWAP="64"
  elif [[ $(awk '/sda$/{printf "%i", $(NF-1) / 1000 / 1000}' /proc/partitions) -gt "160" ]] ; then
    MY_SWAP="32"
  else
    MY_SWAP="16"
  fi
else
  if ! [[ $MY_SWAP =~ ^[0-9]+$ ]] ; then
    echo "error: MY_SWAP is Not a number, specify in GB"
    exit 1
  fi
fi

echo "Set swap size to ${MY_SWAP} GBytes"

#fetching post install
curl "https://raw.githubusercontent.com/hetzneronline/installimage/master/post-install/proxmox5" --output /post-install

#Customising post install file
echo "wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh && bash install-post.sh && rm install-post.sh" >> /post-install

if grep -q '#!/bin/bash' "/post-install"; then
  chmod 777 /post-install
  echo "Starting Installer"

  if [ "$USE_LVM" == "TRUE" ]; then
    $installimage_bin -a -i "root/images/Debian-94-stretch-64-minimal.tar.gz" -g -s en -x /post-install -n "${MY_HOSTNAME}" -b grub -d "sda${MY_RAID_SLAVE}" -r "${MY_RAID_ENABLE}" -l "${MY_RAID_LEVEL}" -p "/:ext4:40G,swap:swap:${MY_SWAP}G,lvm:vg0:all" -v "vg0:data:/var/lib/vz:ext4:all"
  else
    $installimage_bin -a -i "root/images/Debian-94-stretch-64-minimal.tar.gz" -g -s en -x /post-install -n "${MY_HOSTNAME}" -b grub -d "sda${MY_RAID_SLAVE}" -r "${MY_RAID_ENABLE}" -l "${MY_RAID_LEVEL}" -p "/:ext4:all,swap:swap:${MY_SWAP}G"
  fi

else
  echo "Failed to fetch post-install"
  exit 1
fi

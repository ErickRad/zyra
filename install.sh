#!/bin/bash 
set -e

--- Configurations ---

DISK="/dev/sda" 
HOSTNAME="zyra" 
ROOT_PW="linux" 
TIMEZONE="America/Sao_Paulo" 
LOCALE="en_US.UTF-8" 
KEYMAP="br-abnt2"

--- Wipe disk and create partitions ---

sgdisk --zap-all $DISK 
sgdisk -n 1:0:+512M -t 1:8300 -c 1:"boot" $DISK 
sgdisk -n 2:0:0      -t 2:8300 -c 2:"root" $DISK

BOOT="${DISK}1" 
ROOT="${DISK}2" 

mkfs.ext4 $ROOT 
mkfs.ext4 $BOOT

--- Mount filesystems ---

mount $ROOT /mnt 
mkdir /mnt/boot 
mount $BOOT /mnt/boot

--- Install base packages ---

pacstrap /mnt base base-devel linux linux-headers vim networkmanager sudo grub

--- Generate fstab ---

genfstab -U /mnt >> /mnt/etc/fstab

--- Chroot and basic configuration ---

arch-chroot /mnt << "EOF"

echo "$HOSTNAME" > /etc/hostname

echo "$LOCALE UTF-8" > /etc/locale.gen locale-gen 
echo "LANG=$LOCALE" > /etc/locale.conf

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 
hwclock --systohc

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

cat << EOT > /etc/hosts 
127.0.0.1   localhost 
::1         localhost 
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME 
EOT

echo "root:$ROOT_PW" | chpasswd

systemctl enable NetworkManager

grub-install --target=i386-pc $DISK 
grub-mkconfig -o /boot/grub/grub.cfg 
EOF

echo "Installation completed! Remove the live USB and reboot."


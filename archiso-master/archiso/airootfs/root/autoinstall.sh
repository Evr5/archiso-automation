#!/bin/bash

# Configurer le clavier en belge
loadkeys be

# Mettre à jour l'horloge système
timedatectl set-ntp true

# Demander à l'utilisateur de choisir le disque à partitionner
echo "Liste des disques disponibles:"
lsblk -d -n -p -o NAME,SIZE

echo "Entrez le disque sur lequel installer Arch Linux (ex: /dev/sda):"
read DISK

# Vérifier que le disque existe
if [ ! -b "$DISK" ]; then
    echo "Le disque $DISK n'existe pas. Exiting."
    exit 1
fi

# Partitionnement du disque
parted $DISK --script mklabel gpt
parted $DISK --script mkpart primary fat32 1MiB 513MiB
parted $DISK --script set 1 esp on
parted $DISK --script mkpart primary linux-swap 513MiB 32.5GiB
parted $DISK --script mkpart primary ext4 32.5GiB 100%

# Formater les partitions
mkfs.fat -F32 ${DISK}1
mkswap ${DISK}2
mkfs.ext4 ${DISK}3

# Activer le swap
swapon ${DISK}2

# Monter les partitions
mount ${DISK}3 /mnt
mkdir /mnt/boot
mount ${DISK}1 /mnt/boot

# Installer les paquets de base
pacstrap /mnt base linux linux-firmware

# Générer le fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Demander le nom de l'utilisateur
echo "Entrez le nom de l'utilisateur :"
read USERNAME

# Demander le mot de passe de l'utilisateur
echo "Entrez le mot de passe pour l'utilisateur $USERNAME :"
read -s USERPASS

# Demander le mot de passe root
echo "Entrez le mot de passe pour root :"
read -s ROOTPASS

# Chroot dans le nouveau système
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Brussels /etc/localtime
hwclock --systohc
echo "fr_BE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=fr_BE.UTF-8" > /etc/locale.conf
echo "KEYMAP=be" > /etc/vconsole.conf
echo "archlinux" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   archlinux.localdomain archlinux" >> /etc/hosts
pacman -Syu --noconfirm grub efibootmgr networkmanager sudo
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$ROOTPASS" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
pacman -S --noconfirm hyprland
exit
EOF

# Démonter les partitions et redémarrer
umount -R /mnt
reboot

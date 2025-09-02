#!/usr/bin/env bash
set -euo pipefail

targetRoot="/mnt/zyra-root"
zyraName="Zyra Linux"
zyraPretty="Zyra"
zyraId="zyra"
zyraVersion="1.0"
zyraCodename="genesis"
debianSuite="stable"
debianMirror="http://deb.debian.org/debian"
withKernel="no"

if [[ "${1:-}" == "--with-kernel" ]]; then
  withKernel="yes"
fi

requireRoot() { [[ "$(id -u)" -eq 0 ]]; }
installHostDeps() { pacman -Sy --noconfirm --needed debootstrap arch-install-scripts wget gnupg ca-certificates; }
prepareRoot() { mkdir -p "$targetRoot"; debootstrap --arch=amd64 "$debianSuite" "$targetRoot" "$debianMirror"; }
bindMounts() {
  cp /etc/resolv.conf "$targetRoot/etc/resolv.conf"
  mount -t proc proc "$targetRoot/proc"
  mount --rbind /sys "$targetRoot/sys" && mount --make-rslave "$targetRoot/sys"
  mount --rbind /dev "$targetRoot/dev" && mount --make-rslave "$targetRoot/dev"
  mount --rbind /run "$targetRoot/run" && mount --make-rslave "$targetRoot/run"
}
doChroot() {
  arch-chroot "$targetRoot" /bin/bash -eu -c "
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y apt-utils gnupg ca-certificates locales
    sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen || true
    locale-gen
    echo '$zyraPretty' > /etc/hostname
    printf '127.0.1.1\t$zyraId\n' >> /etc/hosts

    printf 'deb $debianMirror $debianSuite main contrib non-free non-free-firmware\n' > /etc/apt/sources.list
    apt-get update

    dpkg-divert --local --rename --add /etc/os-release
    dpkg-divert --local --rename --add /etc/issue
    dpkg-divert --local --rename --add /etc/motd
    dpkg-divert --local --rename --add /etc/debian_version

    cat > /etc/os-release <<EOF
NAME=\"$zyraName\"
PRETTY_NAME=\"$zyraPretty\"
ID=$zyraId
VERSION=\"$zyraVersion\"
VERSION_CODENAME=$zyraCodename
HOME_URL=\"https://$zyraId.local\"
EOF

    printf '$zyraName \\n \\l\n' > /etc/issue
    printf 'Welcome to $zyraName\n' > /etc/motd
    printf '$zyraPretty $zyraVersion\n' > /etc/debian_version

    cat > /etc/lsb-release <<EOF
DISTRIB_ID=$zyraPretty
DISTRIB_RELEASE=$zyraVersion
DISTRIB_CODENAME=$zyraCodename
DISTRIB_DESCRIPTION=\"$zyraName\"
EOF

    echo 'ZYRA_ID=$zyraId' > /etc/zyra-release
    echo 'ZYRA_RELEASE=$zyraVersion' >> /etc/zyra-release

    apt-get install -y bash-completion sudo vim less net-tools iproute2 wget curl lsb-release
    if [[ \"$withKernel\" == \"yes\" ]]; then
      apt-get install -y systemd-sysv linux-image-amd64 grub-pc
      if [[ -f /etc/default/grub ]]; then
        sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"$zyraPretty\"/' /etc/default/grub || true
      fi
      update-initramfs -u || true
    fi

    update-alternatives --set editor /usr/bin/vim.basic || true

    mkdir -p /etc/apt/preferences.d
    cat > /etc/apt/preferences.d/zyra-branding.pref <<EOF
Package: base-files
Pin: release *
Pin-Priority: -1
EOF

    mkdir -p /etc/update-motd.d
    printf '#!/bin/sh\nprintf \"$zyraName\\n\"' > /etc/update-motd.d/00-zyra
    chmod +x /etc/update-motd.d/00-zyra || true
  "
}
cleanupMounts() {
  umount -R "$targetRoot/run" || true
  umount -R "$targetRoot/dev" || true
  umount -R "$targetRoot/sys" || true
  umount -R "$targetRoot/proc" || true
}
packageTarball() {
  tarball="/root/zyra-rootfs-${zyraVersion}.tar.xz"
  tar -C "$targetRoot" -cvpJf "$tarball" . >/dev/null
  echo "Rootfs saved at: $tarball"
}

requireRoot
installHostDeps
prepareRoot
bindMounts
doChroot
cleanupMounts
packageTarball
echo "Done. Mount point: $targetRoot"
echo "Tip: run with --with-kernel to install kernel and grub inside chroot."
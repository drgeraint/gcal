#! /bin/sh

# Adapted from instructions at # 2014-08-18:
# https://help.ubuntu.com/community/LiveCDCustomization 

# Dependencies can be obtained with: apt-get install uck

SOURCE_ISO=~/iso/lubuntu-14.04.1-desktop-i386.iso
OUTPUT_ISO=~/iso/lubuntu-14.04.1-desktop-i386-moodle.iso
DATE=$(date --iso)
VOLUME_TAG="14.04.1 Remastered ${DATE}"
TEMP_DIR=$(mktemp -d tmp-remaster-${DATE}.XXX)

mkdir -p ${TEMP_DIR}/mnt
mkdir -p ${TEMP_DIR}/extract-cd
cd ${TEMP_DIR}

mount -o loop ${SOURCE_ISO} mnt

rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract-cd
unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit

cat <<EOF > edit/etc/resolv.conf
nameserver 8.8.8.8 # Google DNS
nameserver 8.8.4.4 # Google DNS
EOF

cat <<EOF > edit/etc/hosts
127.0.0.1	localhost

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

mount --bind /dev/ edit/dev

cp /usr/local/bin/iso-remaster.sh /usr/local/bin/iso-remaster-chroot.sh edit/usr/local/bin/
chroot edit /bin/sh -c /usr/local/bin/iso-remaster-chroot.sh

umount -l edit/dev

chmod +x extract-cd/casper/filesystem.manifest
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extract-cd/casper/filesystem.manifest
mksquashfs edit extract-cd/casper/filesystem.squashfs -comp xz -e edit/boot
chmod +w extract-cd/README.diskdefines
printf $(du -sx --block-size=1 edit | cut -f1) > extract-cd/README.diskdefines

cd extract-cd
rm md5sum.txt
find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt
mkisofs -D -r -V "${VOLUME_TAG}" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${OUTPUT_ISO} .
umount ${SOURCE_ISO}

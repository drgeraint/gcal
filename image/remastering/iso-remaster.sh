#! /bin/bash

# Adapted from instructions at # 2014-08-18:
# https://help.ubuntu.com/community/LiveCDCustomization 

date
apt-get install -y build-essential genisoimage git

SOURCE_ISO=~/iso/lubuntu-14.04.1-desktop-i386.iso
OUTPUT_ISO=~/iso/lubuntu-14.04.1-desktop-i386-moodle.iso
# MOODLE_DAT=~/gcal/image/remastering/iso-remaster-moodledata.tgz
DATE=$(date --iso)
VOLUME_TAG="14.04.1 Remastered ${DATE}"
TEMP_DIR=$(mktemp -d tmp-remaster-${DATE}.XXX)

mkdir -p ${TEMP_DIR}/mnt
mkdir -p ${TEMP_DIR}/extract-cd
pushd $TEMP_DIR

mount -o loop $SOURCE_ISO mnt

rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract-cd
unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit

mkdir -p /edit/etc/default
mkdir -p /edit/etc/firefox

cat <<EOF > edit/etc/hosts
127.0.0.1	localhost

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat <<EOF > edit/etc/resolv.conf
nameserver 8.8.8.8 # Google DNS
nameserver 8.8.4.4 # Google DNS
EOF

perl -pi -e "s/'us'/'gb'/" edit/usr/lib/ubiquity/ubiquity/misc.py

cat <<EOF > edit/etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="gb"
XKBVARIANT=""
XKBOPTIONS=""
EOF

cat <<EOF > edit/etc/default/locale
LC_ALL=en_GB.utf8
LANG=en_GB:utf8
LANGUAGE=en_GB:en
EOF

# QTIWorks
pushd edit/usr/local/src
git clone https://github.com/davemckain/qtiworks.git
git checkout production
popd

# Moodle
mkdir -p edit/var/www/html
pushd edit/var/www/html
git clone git://git.moodle.org/moodle.git
pushd moodle
git branch -a
git branch --track MOODLE_27_STABLE origin/MOODLE_27_STABLE
git checkout MOODLE_27_STABLE
popd
popd

mkdir edit/var/moodledata
cat <<EOF > edit/var/moodledata/.htaccess
order deny,allow
deny from all
EOF
chown -R www-data.www-data edit/var/moodledata

cp /usr/local/bin/iso-remaster.sh /usr/local/bin/iso-remaster-chroot.sh edit/usr/local/bin/

mount --bind /dev/ edit/dev
mount --bind /var/run/dbus edit/var/run/dbus

chroot edit /bin/sh -c /usr/local/bin/iso-remaster-chroot.sh

rm -f edit/var/lib/dbus/machine-id
umount -l edit/var/run/dbus
umount -l edit/dev

for d in $(find edit/ -type d -name .git); do rm -rf edit/$d ; done
rm -rf edit/tmp/* edit~/root/bash_history
rm -f edit/etc/hosts

# Apache
echo "ServerName localhost" >> edit/etc/apache2/apache2.conf

# Firefox homepage
cat <<EOF > edit/etc/firefox/syspref.js
// This file can be used to configure global preferences for Firefox
user_pref("browser.startup.homepage", "localhost/moodle|www.mathcentre.ac.uk");
EOF

# Midori homepage
sed -e "sXfile:///usr/share/ubuntu-artwork/home/index.htmlXhttp://localhost/moodleX" edit/etc/xdg/midori/config > edit/etc/xdg/midori/config.ed
mv edit/etc/xdg/midori/config.ed edit/etc/xdg/midori/config 

# # Install prepared /var/moodledata 
# pushd edit
# tar -xzf $MOODLE_DAT
# popd
# chown -R www-data.www-data edit/var/moodledata

# Configure STACK
# pushd edit/var/www/html/moodle/
# git clone git://github.com/maths/moodle-qbehaviour_dfexplicitvaildate.git question/behaviour/dfexplicitvaildate
# git clone git://github.com/maths/moodle-qbehaviour_dfcbmexplicitvaildate.git question/behaviour/dfcbmexplicitvaildate
# git clone git://github.com/maths/moodle-qbehaviour_adaptivemultipart.git question/behaviour/adaptivemultipart
# echo "Log into Moodle as admin and click on notifications"
# git clone git://github.com/maths/moodle-qtype_stack.git question/type/stack
# git clone git://github.com/maths/quiz_stack.git mod/quiz/report/stack
# git clone git://github.com/maths/moodle-qformat_stack.git question/format/stack
# echo Login to Moodle as admin and attend to notifications.
# echo Then run the healthcheck from Plugins | Question types | STACK
# popd

# Configure MathJax
# pushd edit/var/www/html/moodle/lib
# git clone git://github.com/mathjax/MathJax.git MathJax
# mv MathJax mathjax
# echo Set the Additional HTML section in the Appearance on Moodle:
# echo Within head
# cat << EOF
# <script type="text/x-mathjax-config"> MathJax.Hub.Config({
# MMLorHTML: { prefer: "HTML" },
# tex2jax: {
# displayMath: [['\\[', '\\]']],
# inlineMath: [['\\(', '\\)']],
# processEscapes: true
# },
# TeX: { extensions: ['enclose.js'] }
# });
# </script>
# <script type="text/javascript" src="/moodle/lib/mathjax/MathJax.js?config=TeX-AMS_HTML"></script>
# EOF
# popd $TEMP_DIR

# Optimise maxima
# apt-get install gcl
# echo Start maxima and enter the following commands:
# echo load("edit/var/moodledata/stack/maximalocal.mac");
# echo :lisp (si::save-system "/tmp/maxima-optimised")
# echo quit();
# echo
# echo mv /tmp/maxima-optimised edit/var/moodledata/stack/maxima-optimised
# echo
# echo Set the maxima command to:
# echo edit/var/moodledata/stack/maxima-optimised -eval '(cl-user::run)'

chmod +x extract-cd/casper/filesystem.manifest
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extract-cd/casper/filesystem.manifest
mksquashfs edit extract-cd/casper/filesystem.squashfs -comp xz -e edit/boot
chmod +w extract-cd/README.diskdefines
printf $(du -sx --block-size=1 edit | cut -f1) > extract-cd/README.diskdefines

pushd extract-cd
chmod u+w isolinux
chmod u+w isolinux/txt.cfg
cat isolinux/txt.cfg | \
sed 's#\(append.*--\)#\1 locale=en_GB.utf8 console-setup/layoutcode=uk#' > isolinux/txt.cfg.ed
cp isolinux/txt.cfg.ed isolinux/txt.cfg

cat <<EOF >> preseed/lubuntu.seed
# Locale and keyboard settings
d-i debian-installer/locale string en_GB.utf8
d-i localechooser/supported-locales en_GB.utf8, en_US.utf8
d-i keyboard-configuration/layout string gb
d-i keyboard-configuration/layoutcode string gb
d-i keyboard-configuration/modelcode string pc105
keyboard-configuration keyboard-configuration/layout string gb
keyboard-configuration keyboard-configuration/layoutcode string gb
keyboard-configuration keyboard-configuration/modelcode string pc105
EOF
rm md5sum.txt
find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat > md5sum.txt
mkisofs -D -r -V "${VOLUME_TAG}" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${OUTPUT_ISO} .
umount ${SOURCE_ISO}


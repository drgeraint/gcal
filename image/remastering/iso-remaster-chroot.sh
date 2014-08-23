#! /bin/sh

# This should be run in chroot edit

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

export HOME=/root
export LC_ALL=en_GB.utf8
export LANG=en_GB:utf8
export LANGUAGE=en_GB:en
export LC_CTYPE=en_GB.utf8
export LC_NUMERIC=en_GB.utf8
export LC_TIME=en_GB.utf8
export LC_COLLATE=en_GB.utf8
export LC_MONETARY=en_GB.utf8
export LC_MESSAGES=en_GB.utf8
export LC_PAPER=en_GB.utf8
export LC_NAME=en_GB.utf8
export LC_ADDRESS=en_GB.utf8
export LC_TELEPHONE=en_GB.utf8
export LC_MEASUREMENT=en_GB.utf8
export LC_IDENTIFICATION=en_GB.utf8

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

# alias packages='dpkg-query -W --showformat="\${Installed-Size}\t\${Package}\n" | sort -nr'

doc_removes=$(dpkg-query -W --showformat="\${Package}\n" | grep doc$)
removes="$doc_removes"
for f in abiword gnumeric goffice guvcview leafpad mtpaint pidgin sylpheed transmission xpad; do
    r=$(dpkg-query -W --showformat="\${Package}\n" | grep $f);
    removes="$removes $r";
done
for lang in de es fr ru ; do
    removes="$removes language-pack-${lang}"
    removes="$removes language-pack-${lang}-base"
    removes="$removes language-pack-gnome-${lang}"
    removes="$removes language-pack-gnome-${lang}-base"
    removes="$removes firefox-locale-${lang}"
done

apt-get -y purge ${removes}
apt-get -y clean

additions="apache2 mysql-server mysql-client"
additions="$additions libapache2-mod-php5 php5-common php5-mysql php5-curl php5-gd php5-xmlrpc php5-intl"
# apache2-utils ssl-cert
# STACK
# additions="$additions gnuplot maxima libjs-mathjax"

echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
apt-get -y install $additions

# Configure MySQL
mysql -u root --password=password <<EOF
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'password';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON moodle.* TO moodleuser@localhost IDENTIFIED BY 'password';
EOF

apt-get -y --purge autoremove
apt-get clean

rm -f /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts

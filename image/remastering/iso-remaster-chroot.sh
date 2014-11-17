#! /bin/sh

# This should be run in chroot edit

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

ibus engine xkb:gb:extd:eng
echo "Europe/London" > /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata
localectl set-locale LANG=en_GB.utf8 LANGUAGE=en_GB:en LC_ALL=en_GB.utf8
localectl set-keymap gb
localectl set-x11-keymap gb
update-locale 

# alias packages='dpkg-query -W --showformat="\${Installed-Size}\t\${Package}\n" | sort -nr'

doc_removes=$(dpkg-query -W --showformat="\${Package}\n" | grep doc$)
removes="$doc_removes"
for f in abiword firefox gnumeric goffice guvcview leafpad mtpaint pidgin sylpheed transmission xfburn xpad; do
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
removes="$removes libavcodec.*"
buildtools="default-jdk maven"
additions="apache2 mysql-server mysql-client midori libapache2-mod-php5 php5-common php5-mysql php5-curl php5-gd php5-xmlrpc php5-intl maxima tomcat7 apache2-utils ssl-cert"
# additions="$additions gnuplot maxima libjs-mathjax" # for Stack 

echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections

# https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/1325142
echo "libpam-systemd hold"|dpkg --set-selections

apt-get update 
apt-get -y purge ${removes}
apt-get -y clean
apt-get -y dist-upgrade
#apt-get -y autoremove
apt-get -y install $buildtools
apt-get -y install $additions

# Configure MySQL
mysql -u root --password=password <<EOF
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'password';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON moodle.* TO moodleuser@localhost IDENTIFIED BY 'password';
EOF

CLIDIR=/var/www/html/moodle/admin/cli
chmod -R +x ${CLIDIR}
php -f ${CLIDIR}/install.php -- \
    --lang=en  \
    --wwwroot='http://localhost/moodle' \
    --dataroot='/var/moodledata' \
    --dbtype='mysqli' \
    --dbhost='localhost' \
    --dbname='moodle' \
    --dbuser='moodleuser' \
    --dbpass='password' \
    --dbport='' \
    --dbsocket='' \
    --prefix='mdl_' \
    --fullname='GCU Computer Aided Learning (Mathematics for Engineers)' \
    --shortname='gcal' \
    --adminuser='admin' \
    --adminpass='(s+A)*(s+B)=s^2+(A+B)*s+A*B' \
    --non-interactive --agree-license 

chown -R www-data.www-data /var/www
chown -R www-data.www-data /var/moodledata

# Install QTIWorks
cd /usr/local/src/qtiworks
mvn install
# cd ..
# rm -rf /usr/local/src/qtiworks

# apt-get -y --purge $buildtools
apt-get -y --purge autoremove
apt-get clean

rm -f /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts

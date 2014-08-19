#! /bin/sh

# This should be run in chroot edit

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

export HOME=/root
export LC_ALL=C

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

alias packages='dpkg-query -W --showformat="\${Installed-Size}\t\${Package}\n" | sort -nr'

removes="abiword* gnumeric* goffice* guvcview* pidgin* sylpheed* transmission*"
for lang in de es fr ru ; do \
    removes="$removes language-pack-${lang}"
    removes="$removes language-pack-${lang}-base"
    removes="$removes language-pack-gnome-${lang}"
    removes="$removes language-pack-gnome-${lang}-base"
    removes="$removes firefox-locale-${lang}"
done
echo $removes

apt-get -y purge ${removes}
apt-get -y clean

cat <<EOF >> /etc/firefox/syspref.js
user_pref("browser.startup.homepage", "www.gcu.ac.uk|www.mathcentre.ac.uk|www.mathtutor.ac.uk");
EOF

rm -rf /tmp/* ~/.bash_history
rm /var/lib/dbus/machine-id
rm /sbin/initctl
rm /etc/hosts
dpkg-divert --rename --remove /sbin/initctl
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts

#! /bin/sh

# This should be run in chroot edit
echo *** Configuring chroot filesystem ***

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

export HOME=/root
export LC_ALL=C

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

alias packages='dpkg-query -W --showformat="\${Installed-Size}\t\${Package}\n" | sort -nr'

# Unwanted packages
echo *** Removing unwanted packages ***
removes="abiword* gnumeric* goffice* guvcview* leafpad pidgin* sylpheed* transmission* xpad"
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

echo *** Adding new packages ***
# Build tools
tmp_additions="build-essential git"
# LAMP
additions="apache2 apache2-utils ssl-cert"
additions="$additions mysql-server mysql-client"
additions="$additions libapache2-mod-php5 php5-common php5-mysql php5-curl php5-gd php5-xmlrpc php5-intl"
# STACK
# additions="$additions gnuplot maxima libjs-mathjax"

echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
apt-get -y install ${tmp_additions} ${additions}
apachectl -k stop

# Configure MySQL
echo *** Configuring MySQL ***
mysql -u root --password=password <<EOF
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON moodle.* TO moodleuser@localhost IDENTIFIED BY 'password';
EOF
service mysql stop

# Configure Moodle
echo *** Configuring Moodle ***
cd /var/www
git clone git://git.moodle.org/moodle.git
cd moodle
git branch -a
git branch --track MOODLE_26_STABLE origin/MOODLE_26_STABLE
git checkout MOODLE_26_STABLE

# Configure STACK
# echo *** Configuring STACK ***
# cd /var/www/moodle/
# git clone git://github.com/maths/moodle-qbehaviour_dfexplicitvaildate.git question/behaviour/dfexplicitvaildate
# git clone git://github.com/maths/moodle-qbehaviour_dfcbmexplicitvaildate.git question/behaviour/dfcbmexplicitvaildate
# git clone git://github.com/maths/moodle-qbehaviour_adaptivemultipart.git question/behaviour/adaptivemultipart
# echo "Log into Moodle as admin and click on notifications"
# cd /var/www/moodle
# git clone git://github.com/maths/moodle-qtype_stack.git question/type/stack
# git clone git://github.com/maths/quiz_stack.git mod/quiz/report/stack
# git clone git://github.com/maths/moodle-qformat_stack.git question/format/stack
# echo Login to Moodle as admin and attend to notifications.
# echo Then run the healthcheck from Plugins | Question types | STACK

# Configure MathJax
# echo *** Configuring MathJax ***
# cd /var/www/moodle/lib
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

# Optimise maxima -- FIXME
# echo *** Optimising Maxima ***
# apt-get install gcl
# echo Start maxima and enter the following commands:
# echo load("/var/moodledata/stack/maximalocal.mac");
# echo :lisp (si::save-system "/tmp/maxima-optimised")
# echo quit();
# echo
# echo mv /tmp/maxima-optimised /var/moodledata/stack/maxima-optimised
# echo
# echo Set the maxima command to:
# echo /var/moodledata/stack/maxima-optimised -eval '(cl-user::run)'

# Configure Firefox
echo *** Configuring Firefox ***
cat <<EOF >> /etc/firefox/syspref.js
user_pref("browser.startup.homepage", "127.0.0.1/moodle|www.mathcentre.ac.uk|www.mathtutor.ac.uk|www.gcu.ac.uk");
EOF

echo *** Removing unnecessary files ***
apt-get -y purge ${tmp_additions} 
apt-get -y --purge autoremove
apt-get clean
for d in $(find / -type d -name .git); do rm -rf $d ; done
rm -rf /tmp/* ~/.bash_history
rm -f /var/lib/dbus/machine-id
rm -f /etc/hosts
rm -f /sbin/initctl

echo *** Preparing to exit chroot ***
dpkg-divert --rename --remove /sbin/initctl
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts

echo *** End of chroot ***

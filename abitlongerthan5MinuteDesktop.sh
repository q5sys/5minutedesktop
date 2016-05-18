#!/bin/csh
#
# FreeBSD 5 Minute Desktop Build
#
# Version: 1.1
#
# Tested on FreeBSD/HardenedBSD default install with ports
# Tested on VirtualBox with Guest Drivers Installed
# 
# Copyright (c) 2016, Michael Shirk
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this 
# list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, 
# this list of conditions and the following disclaimer in the documentation 
# and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

setenv PATH "/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:/root/bin"

#pkgng needs to be bootstrapped. 
env ASSUME_ALWAYS_YES=YES pkg bootstrap

#Update Packages
env ASSUME_ALWAYS_YES=YES pkg update -f

#Install everything
pkg install -y xorg-server xinit xauth xscreensaver xf86-input-keyboard xf86-input-mouse qt5 xbrightness poppler-qt5

#Lumina Specific
wget https://github.com/pcbsd/lumina/archive/master.zip -O /tmp/lumina-master.zip && unzip /tmp/lumina-master.zip && cd /tmp/lumina-master && /usr/local/lib/qt5/bin/qmake ./lumina.pro && make && make install

#PCBSD Specific
wget https://github.com/pcbsd/pcbsd/archive/master.zip -O /tmp/pcbsd-master.zip && unzip /tmp/pcbsd-master.zip
cd /tmp/pcbsd-master/src-qt5/libpcbsd/ && /usr/local/lib/qt5/bin/qmake ./libpcbsd.pro && make && make install
cd /tmp/pcbsd-master/src-qt5/PCDM/ && /usr/local/lib/qt5/bin/qmake ./PCDM.pro && make && make install

#enable PDCM
cat << EOF >> /etc/rc.conf
pcdm_enable="YES"
EOF

#set up trigger for PCDM
sed -i '' 's/TWM/PCDMd/' /usr/local/lib/X11/xinit/xinirc

#generate machin-id for Lumina
dbus-uuidgen > /etc/machine-id

#enable sudo
sed -e 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /usr/local/etc/sudoers

NO CHANGES YET BELOW THIS LINE

#Other stuff to make life eaiser
pkg install -y rxvt-unicode zsh sudo chromium tmux libreoffice gnupg pinentry-curses en-aspell en-hunspell

#necessary for linux compat and chrome/firefox
echo 'sem_load="YES"' >> /boot/loader.conf
echo 'linux_load="YES"' >> /boot/loader.conf

#replaces systemd on FreeBSD with faster booting
echo 'autoboot_delay="1"' >> /boot/loader.conf

#rc updates for X
cat << EOF >> /etc/rc.conf
hald_enable="YES"
dbus_enable="YES"
EOF

#sysctl values for chromium,audio and disabling CTRL+ALT+DELETE
cat << EOF >> /etc/sysctl.conf
#Required for chrome
kern.ipc.shm_allow_removed=1
#Don't allow CTRL+ALT+DELETE
hw.syscons.kbd_reboot=0
# fix for HDA sound playing too fast/too slow. only if needed.
dev.pcm.0.play.vchanrate=44100
EOF

#If running on HardenedBSD, configure applications to work.
set HARD = `sysctl hardening.version`
if ( $status == 0 ) then
	#install secadm from HardenedBSD pkg repo
	pkg install -y secadm

	#setup secadm module to load at boot
	echo 'secadm_load="YES"' >> /boot/loader.conf

	#create the current application rules for secadm
	#based on v0.3 rules from https://github.com/HardenedBSD/secadm-rules
	cat << EOF >> /usr/local/etc/secadm.rules
secadm {
        pax {
                path: "/usr/local/share/chromium/chrome",
                  mprotect: false,
                  pageexec: false,
        },
        pax {
                path: "/usr/local/lib/libreoffice/program/soffice.bin",
                  mprotect: false,
                  pageexec: false,
        },
}
EOF

	chmod 0500 /usr/local/etc/secadm.rules
	chflags schg /usr/local/etc/secadm.rules

	#set secadm to start at bootime
	cat << EOF >> /etc/rc.conf
secadm_enable="YES"
EOF
fi

#reboot for all modules and services to start
reboot


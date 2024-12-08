# deb-verify

Shell script to verify the contents and file permissions (file security attributes) of the installed deb-packages

It allows Debian user to verify the deb-package on the file level like `rpm --verify` / `rpm -V` does on the RPM-based systems. 
It is known that `dpkg --verify --verify-format=rpm` currently can report only missing files, but not their permissions/attributes.
So the below commands will fail:

```
sudo apt-get install mc
sudo chmod a-x /usr/bin/mc
dpkg --verify --verify-format=rpm mc
```

while 

```
sudo rm /usr/bin/mc
dpkg --verify --verify-format=rpm mc
```

will work and duplicate the functionality of `debsums --silent mc`.

To use this script on the single package use the following commands:

```
sudo apt-get install wget

cd ~/Downloads
wget -c https://raw.githubusercontent.com/N0rbert/deb-verify/master/deb-verify.sh 
chmod a+x deb-verify.sh
sudo cp -pv deb-verify.sh /usr/local/bin/deb-verify.sh

sudo apt-get install --reinstall mc
cd /tmp
apt-get download mc
sudo chmod a-x /usr/bin/mc
deb-verify.sh -p mc -d mc_*.deb

sudo rm /usr/bin/mcedit
deb-verify.sh -p mc -d mc_*.deb -m l

sudo rm -rf /usr/share/doc/mc
deb-verify.sh -p mc -d mc_*.deb
deb-verify.sh -p mc -d mc_*.deb -m d

sudo apt-get install --reinstall mc
```

For the full system check use the below commands running as root:

```
apt-get clean
apt-get update
apt-get dist-upgrade
apt-get autoremove

apt-get install --reinstall --download-only $(dpkg -l | grep ^ii | awk '{print $2}')
cd /var/cache/apt/archives
for d in   *_all.deb; do deb-verify.sh -p $(echo $d | awk -F_ '{print $1}') -d $d -q; done
for d in *_amd64.deb; do deb-verify.sh -p $(echo $d | awk -F_ '{print $1":amd64"}') -d $d -q; done
for d in  *_i386.deb; do deb-verify.sh -p $(echo $d | awk -F_ '{print $1":i386"}') -d $d -q; done
```

This script was tested on Debian 10, 11 and 12 with usrmerge applied/installed.

Known issues and limitations:

* usrmerge may cause inaccurate results, this will be fixed later;
* packages with hard-links need manual check;
* packages with SUID bits need manual check;
* on the system with enabled debian-backports user should recheck such packages manually according to their versions and real origin.


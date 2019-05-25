#/bin/sh

echo "Initializing Environment"
basedir=$PWD
arch=$(arch)
echo "arch is $arch"

[ $arch == "i686" ] && arch="i386"
[ $arch == "x86_64" ] && sudo dpkg --add-architecture i386

# remove old installs of oracle java
sudo apt-get remove --purge oracle-java* oracle-instant*

# update
sudo apt-get update

# install base dependencies
if [[ $arch == "i386" ]]; then
	echo "Setting up 32 bit build env..."
	sudo apt-get install build-essential zlib1g-dev libpcre3-dev psmisc \
		libboost-dev libxml2-dev libncurses5-dev flex bison git-core alien libaio1 \
		python-ply bc libcurl4-gnutls-dev clang-3.9 ant curl -y
else
	echo "Setting up 64 bit build env..."
	sudo apt-get install lib32z1 lib32ncurses5 g++-6-multilib gcc-6-multilib clang-3.9 zlib1g-dev:i386 libc6:i386 psmisc clang \
		libc6-dev:i386 libc6-i686:i386 libgcc1:i386 linux-libc-dev:i386 \
		zlib1g:i386 libpcre3-dev:i386 libxml2-dev:i386 libncurses5-dev:i386 \
		flex bison git-core alien libaio1:i386 python-ply bc libaio1 \
		libboost-dev build-essential libc6-dbg:i386 libc6-dbg libcurl4-gnutls-dev:i386 ant curl -y

	sudo apt-get remove libxml2-dev:amd64 libncurses-dev:amd64 zlib1g-dev:amd64
fi

# install dependencies for stationapi
sudo apt-get install libboost-dev libboost-program-options-dev sqlite3 libsqlite3-dev -y

# install cxmake from src to fix CXX17 problems
cd /tmp
wget http://www.cmake.org/files/v3.8/cmake-3.8.2.tar.gz && \
     tar xf cmake-3.8.2.tar.gz && \
     cd cmake-3.8.2            && \
     ./configure               && \
     make && sudo make install

# install git lfs
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
sudo apt install git-lfs -y

# prepare to install external dependencies
cd $basedir
rm -rf dependencies/
git submodule update --init --recursive

cd dependencies
cp * /tmp
cd /tmp

# install java
tar -xvzf jdk-8u152-linux-i586.tar.gz
sudo mv jdk1.8.0_152/ /opt
sudo ln -s /opt/jdk1.8.0_152 /usr/java

# nuke old versions of oracle instant client
sudo rm -rf /usr/lib/oracle &> /dev/null

# install oracle instant client
if [ $arch == "i386" ]; then
	sudo alien -i oracle-instantclient12.2-basiclite-12.2.0.1.0-1.i386.rpm
	sudo alien -i oracle-instantclient12.2-devel-12.2.0.1.0-1.i386.rpm
	sudo alien -i oracle-instantclient12.2-sqlplus-12.2.0.1.0-1.i386.rpm
else
	sudo alien -i --target=amd64 oracle-instantclient12.2-basiclite-12.2.0.1.0-1.i386.rpm
	sudo alien -i --target=amd64 oracle-instantclient12.2-devel-12.2.0.1.0-1.i386.rpm
	sudo alien -i --target=amd64 oracle-instantclient12.2-sqlplus-12.2.0.1.0-1.i386.rpm
fi

# set env vars
sudo find /usr/lib -lname '/usr/lib/oracle/*' -delete &> /dev/null

sudo touch /etc/profile.d/oracle.sh
sudo touch /etc/ld.so.conf.d/oracle.conf

export ORACLE_HOME="/usr/lib/oracle/12.2/client"
export JAVA_HOME=/usr/java

cd $basedir

# Set java include paths - you want to change these to something like the below for oracle
sudo cp utils/initial-setup/debian/java_ldsoconfd_example.conf /etc/ld.so.conf.d/java.conf
sudo cp utils/initial-setup/debian/java_profile_example.sh /etc/profile.d/java.sh

echo "/usr/lib/oracle/12.2/client/lib" | sudo tee -a /etc/ld.so.conf.d/oracle.conf

echo "export ORACLE_HOME=/usr/lib/oracle/12.2/client" | sudo tee -a /etc/profile.d/oracle.sh
echo "export PATH=\$PATH:/usr/lib/oracle/12.2/client/bin" | sudo tee -a /etc/profile.d/oracle.sh
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/oracle/12.2/client/lib:/usr/include/oracle/12.2/client" | sudo tee -a /etc/profile.d/oracle.sh

source /etc/profile.d/oracle.sh
source /etc/profile.d/java.sh

sudo ln -s /usr/include/oracle/12.2/client $ORACLE_HOME/include

sudo ldconfig

echo "Environment Initialization Complete! You should reboot!"

#!/bin/bash

# Update packages and install openvpn
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install openvpn

# Read the local and public IP addresses from the user
echo "Enter your Raspberry Pi's local IP address:"
read LOCALIP
echo "Enter your network's public IP address:"
read PUBLICIP
# Ask user for desired level of encryption
echo "1024 or 2048 bit encryption? 2048 is more secure but will take much longer to set up."
echo "Enter your choice, 1024 or 2048:"
read ENCRYPT

# Copy the easy-rsa files to a directory inside the new openvpn directory
cp -r /usr/share/doc/openvpn/examples/easy-rsa/2.0 /etc/openvpn/easy-rsa

# Edit the EASY_RSA variable in the vars file to point to the new easy-rsa directory,
# And change from default 1024 encryption if desired
cd /etc/openvpn/easy-rsa
sed -i -e 's:"`pwd`":"/etc/openvpn/easy-rsa":' vars
if [ $ENCRYPT = 2048 ]; then
 sed -i -e 's:KEY_SIZE=1024:KEY_SIZE=2048:' vars
fi

# source the vars file just edited
source ./vars

# Remove any previous keys
./clean-all

# Build the certificate authority
./build-ca

# Build the server
./build-key-server server

# Generate Diffie-Hellman key exchange
./build-dh

# Generate static HMAC key to defend against DDoS
openvpn --genkey --secret keys/ta.key

# Write config file for server using the template .txt file
sed 's/LOCALIP/'$LOCALIP'/' </home/pi/OpenVPN-Setup/server.txt >/etc/openvpn/server.conf
if [ $ENCRYPT = 2048 ]; then
 sed -i 's:dh1024:dh2048:' vars
fi

# Enable forwarding of internet traffic
sed -i -e 's:#net.ipv4.ip_forward=1:net.ipv4.ip_forward=1:' /etc/sysctl.conf
sudo sysctl -p

# Write script to allow openvpn through firewall on boot using the template .txt file
sed 's/LOCALIP/'$LOCALIP'/' </home/pi/OpenVPN-Setup/firewall-openvpn-rules.txt >/etc/firewall-openvpn-rules.sh
sudo chmod 700 /etc/firewall-openvpn-rules.sh
sudo chown root /etc/firewall-openvpn-rules.sh
sed -i '/gateway/a \
	pre-up /etc/firewall-openvpn-rules.sh' /etc/network/interfaces

# Write default file for client .ovpn profiles, to be used by the MakeOVPN script, using template .txt file
sed 's/PUBLICIP/'$PUBLICIP'/' </home/pi/OpenVPN-Setup/Default.txt >/etc/openvpn/easy-rsa/keys/Default.txt

# Make directory under home directory for .ovpn profiles
mkdir /home/pi/ovpns

echo "Configuration complete. Restart system to apply changes and start VPN server."

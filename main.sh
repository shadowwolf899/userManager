#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

if echo $TERM | grep "screen" > /dev/null; then
	echo "All good" > /dev/null
else
	echo "You should run this in tmux, else you will lose your progress"
	exit 2
fi
echo "USERS:"
./listusers
echo
echo "Type admins:"
while [ -z "$finAD" ] 
do
	read tempA
	if [ -z "$tempA" ]; then
		finAD="Done"
	else
		authAdmins[${#authAdmins[*]}]=$tempA
	fi
done
echo
echo "Type users:"
while [ -z "$finU" ]
do
	read tempA
	if [ -z "$tempA" ]; then
		finU="Done"
	else
		authUsers[${#authUsers[*]}]=$tempA
	fi
done

for i in $(cat users.txt); do
	if echo ${authUsers[*]} | grep $i > /dev/null || echo ${authAdmins[*]} | grep $i > /dev/null; then
		echo "$i AUTHORIZED"
	else
		echo "DELETE $i (y/N):"
		read reply
		if [[ $reply == "y" ]]; then
			userdel $i
			groupdel $i
		fi
	fi
done

for i in ${authUsers[*]}; do
	if echo $(cat users.txt) | grep $i > /dev/null; then
		echo "$i AUTHORIZED" > /dev/null
	else
		echo "MAKE $i? (y/N)"
		read reply
		if [[ $reply == "y" ]]; then
			useradd $i
		fi
	fi
done

for i in ${authAdmins[*]}; do
	if echo $(cat users.txt) | grep $i > /dev/null; then
		echo "$i AUTHORIZED" > /dev/null
	else
		echo "MAKE $i (admin)? (y/N)"
		read reply
		if [[ $reply == "y" ]]; then
			useradd $i
			usermod -a -G sudo $i
			usermod -a -G wheel $i
		fi
	fi
done

echo "Change passwords? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	echo "Unique passwords per user? (y/N)"
	read reply
	if [[ $reply == "y" ]]; then
		for i in ${authAdmins[*]}; do
			echo $i
			read pass
			echo $i:$pass | chpasswd
		done
		for i in ${authUsers[*]}; do
			echo $i
			read pass
			echo $i:$pass | chpasswd
		done
	else
		echo "Enter admin password:"
		read adPass

		echo "Enter user password:"
		read usPass

		for i in ${authAdmins[*]}; do
			usermod -a -G wheel $i
			usermod -a -G sudo $i
			echo "CHANGING PASSWORD FOR "$i
			echo $i:$adPass | chpasswd
		done
		for i in ${authUsers[*]}; do
			usermod -G $i $i
			echo "CHANGING PASSWORD FOR "$i
			echo $i:$usPass | chpasswd
		done
	fi
fi

echo "Set default password policies? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	echo "Setting minimum length and how many passwords to remember . . ."
	sed -i "s/pam_unix.so/pam_unix.so remember=5 minlen=8/" /etc/pam.d/common-password
	echo "Setting password requirements . . ."
	sed -i 's/pam_cracklib.so/pam_cracklib.so ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' /etc/pam.d/common-password
	echo "Setting password age requirements . . ."
	sed -i -E "s/PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/" /etc/login.defs
	sed -i -E "s/PASS_MIN_DAYS.*/PASS_MIN_DAYS 10/" /etc/login.defs
	sed -i -E "s/PASS_WARN_AGE.*/PASS_WARN_AGE 7/" /etc/login.defs
	echo "auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800" >> /etc/pam.d/common-auth
fi

echo "Lock root? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	passwd -l root
else
	passwd -u root
fi

echo "Remove guest? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	if grep "allow-guest=false" /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf > /dev/null; then
		echo "Already set"
	elif grep "allow-guest" /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf > /dev/null; then
		sed -i -E "s/allow-guest.*/allow-guest=false/" /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf
		service lightdm restart
	else
		echo "allow-guest=false" >> /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf 
		service lightdm restart
	fi
fi

echo "Permit remote root login? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	if grep "PermitRootLogin" /etc/ssh/sshd_config > /dev/null; then
		sed -i -E "s/PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
	else
		echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
	fi
else
	if grep "PermitRootLogin" /etc/ssh/sshd_config > /dev/null; then
		sed -i -E "s/PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
	else
		echo "PermitRootLogin no" >> /etc/ssh/sshd_config
	fi
fi

echo "Enable auto updates? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	if [ -f /etc/apt/apt.conf.d/10periodic ]; then
		sed -i -E "s/Update-Package-Lists.*/Update-Package-Lists \"1\"\;/" /etc/apt/apt.conf.d/10periodic
		sed -i -E "s/Download-Upgradeable-Packages.*/Download-Upgradeable-Packages \"1\"\;/" /etc/apt/apt.conf.d/10periodic
	else
		echo "I don't know how"
	fi
fi

echo "Firewall? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	echo "Block ssh? (y/N)"
	read reply
	if [[ $reply == "y" ]]; then
		ufw deny ssh
	else
		ufw allow ssh
	fi
	ufw enable
	sysctl -n net.ipv4.tcp_syncookies
else
	ufw disable
fi

echo "New sources.list? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	apt-get install curl -y
	if lsb_release -a | grep "12.04" > /dev/null; then
		curl https://repogen.simplylinux.ch/txt/precise/sources_bba61f3485a81e38a79ac3f6ecc2b76c6a9badbe.txt | sudo tee /etc/apt/sources.list
	elif lsb_release -a | grep "14.04" > /dev/null; then
		curl https://repogen.simplylinux.ch/txt/yakkety/sources_024c14347186a4e6e152f4457d7e66bec553bc8d.txt | sudo tee /etc/apt/sources.list
	elif lsb_release -a | grep "16.04" > /dev/null; then
		curl https://repogen.simplylinux.ch/txt/xenial/sources_3dc5770f0c6f81ac011ad9525ef566915636d0be.txt | sudo tee /etc/apt/sources.list
	elif lsb_release -a | grep "16.10" > /dev/null; then
		curl https://repogen.simplylinux.ch/txt/yakkety/sources_024c14347186a4e6e152f4457d7e66bec553bc8d.txt | sudo tee /etc/apt/sources.list
	fi
fi

echo "Perform updates? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	apt-get update
	apt-get upgrade -y
fi

echo "Reboot now? (y/N)"
read reply
if [[ $reply == "y" ]]; then
	reboot
else
	echo "Remember to restart at somepoint"
fi

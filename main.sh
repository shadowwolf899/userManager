#!/usr/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
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
	if echo ${authUsers[*]} | grep $i; then
		echo "$i AUTHORIZED"
	else
		echo "DELETE $i (y/n):"
		read reply
		if [[ $reply == "y" ]]; then
			userdel $i
		fi
	fi
	if echo ${authAdmins[*]} | grep $i; then
		echo "$i AUTHORIZED"
	else
		echo "DELETE $i (y/n):"
		read reply
		if [[ $reply == "y" ]]; then
			userdel $i
		fi
	fi
done

echo "Enter admin password:"
read adPass

echo "Enter user password:"
read usPass

for i in $(seq 0 1 ${#authAdmins[*]}); do
	usermod -a -G wheel ${authAdmins[$i]}
	echo ${authAdmins[$i]}:$adPass | chpasswd
done
for i in $(seq 0 1 ${#authUsers[*]}); do
	usermod -G ${authUsers[$i]} ${authUsers[$i]}
	echo ${authUsers[$i]}:$usPass | chpasswd
done

echo "Set default password policies? (y/n)"
read reply
if [[ $reply == "y" ]]; then
	echo "Setting minimum length and how many passwords to remember . . ."
	sed -i -E "s/pam_unix.so/pam_unix.so remember=5 minlen=8" /etc/pam.d/common-password
	echo "Setting password requirements . . ."
	sed -i -E 's/pam_cracklib.so/pam_cracklib.so ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1' /etc/pam.d/common-pass
	echo "Setting password age requirements . . ."
	sed -i -E "s/PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/" /etc/login.defs
	sed -i -E "s/PASS_MIN_DAYS.*/PASS_MIN_DAYS 10/" /etc/login.defs
	sed -i -E "s/PASS_WARN_AGE.*/PASS_WARN_AGE 7/" /etc/login.defs
	echo "auth required pam_tally2.so deny=5 onerr=fail unlock_time=1800" >> /etc/pamd./common-auth
fi

echo "Lock root? (y/n)"
read reply
if [[ $reply == "y" ]]; then
	passwd -l root
fi

echo "Remove guest? (y/n)"
read reply
if [[ $reply == "y" ]]; then
	if [ -f /etc/lightdm/ligtdm.conf ]; then
		echo allow-guest=false >> /etc/lightdm/lightdm.conf
		restart lightdm
	elif [ -f /usr/share/lightdm/lightdm.conf/50-ubuntu.conf ]; then
		echo allow-guest=false >> /usr/share/lightdm/lightdm/conf/50-ubuntu.conf
		restart lightdm
	elif [ -f /etc/lightdm/lightdm.conf.d/50-unity-greeter.conf ]; then
		echo allow-guest=false >> /etc/lightdm/lightdm.conf.d/50-unity-greeter.conf
		restart lightdm
	elif [ -f /usr/share/lightdm/lightdm.conf.d/50-unity-greeter.conf ]; then
		echo allow-guest=false >> /etc/lightdm/lightdm.conf.d/50-unity-greeter.conf
		restart lightdm
	fi	
fi

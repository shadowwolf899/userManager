#!/usr/bin/bash
echo "USERS:"
./listusers
temp="test"
echo
echo "Type admins:"
while ![ -z "$temp"] 
do
	read temp
	authAdmins=$temp
done
temp="test"
echo
echo "Type users:"
while ![ -z "$temp" ]
do
	read temp
	authUsers=$temp
done
echo $authAdmins
echo $authUsers

#!/usr/bin/python
# This is a basic program for managing user accounts
# Importing modules
import os
import sys

# Check if run as root
if not os.geteuid() == 0:
	sys.exit('Script must be run as root')

# This is the actual program
authUsers=[];
authAdmins=[];
print("USERS:\n");
os.system('./listusers');
print("");
users=open("users.txt").read().splitlines();
temp='This string is useless';
while temp!='':
	temp=raw_input("Enter authorized admins (One at a time): ");
	if temp!='':
		authAdmins.append(temp);
temp='This string is useless';
while temp!='':
	temp=raw_input("Enter authorized standard users (One at a time): ");
	if temp!='':
		authUsers.append(temp);
if len(authAdmins) > 0:
	adminPass=raw_input("Enter a password for the admins: ");
if len(authUsers) > 0:
	userPass=raw_input("Enter a password for the standard users: ");
for i in range(0,len(authAdmins)):
	os.system('echo '+authAdmins[i]+':'+adminPass+' | chpasswd');
for i in range(0,len(authUsers)):
	os.system('echo '+authUsers[i]+':'+userPass+' | chpasswd');

# Deletes any users that exist that aren't authorized
delUsers=[];
for i in range(0,len(users)):
	if users[i] not in authUsers and users[i] not in authAdmins:
		delUsers.append(users[i]);
for i in delUsers:
	if raw_input("DELETE: " + i + "? (y/n): ").lower() == "y":
		os.system("userdel " + i);
		print(i + " DELETED");

# Makes sure groups are set up correctly
os.system("groupadd temp"); # Sets up temp group for standard users
for i in range(0,len(authUsers)):
	os.system("usermod " + authUsers[i] + " -g " + authUsers[i] + " -G temp");
os.system("groupdel temp"); # Deletes temp group so that standard users have no extra groups

# Lock out the root account
if raw_input("Should the root account be locked? (y/n): ").lower() == "y":
	os.system("passwd -l root");
	print("Root account has been locked");
if raw_input("Shoudl the guest account be locked? (y/n): ").lower() == "y":
	if os.path.isfile("/etc/lightdm/lightdm.conf"):
		os.system("echo allow-guest=false >> /etc/lightdm/lightdm.conf");
		os.system("restart lightdm");
	elif os.path.isfile("/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf"):
		os.system("echo allow-guest=false >> /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf");
		os.system("restart lightdm");
	else:
		print("ERROR: No known config file exists");

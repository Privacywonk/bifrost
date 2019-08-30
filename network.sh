###############################################################
# Network Switcher for LTE Rpi 
# v1.0
# email: privacywonk@privacywonk.net
# date: 2019-08-30
# Instructions:
# Edit the file below to change iface and pingip variables
# to your specific environment
#
###############################################################

#!/bin/bash

iface="eth0"            # which interface to bring up/down
pingip='8.8.8.8'        # what to ping

ping -I "$iface" -c 2 -q "$pingip"

if [ "$?" -eq 0 ]; then       # if ping succeeds on primary WAN interface, turn off ppp 
	if [ "$(/bin/pidof pppd)" ]
	then
		printf ":::(1) ping succeeded and pppd running. Turn it off\n"
		/usr/bin/wall "LTE Network is about to turn off. Save all work. Network switching over in 60 seconds!"
    		sleep 60	    
		/usr/bin/poff
		logger "LTE Network OFF: `date`"
	else
		printf ":::(3) ping succeded and pppd *not* running. Exit\n"
		exit
	fi
else
	if [ "$(/bin/pidof pppd)" ] 
	then
		printf "::: (4) ping failed and pppd already running. Exit\n"
		exit #pppd is already running. Do not start another one
	else
		printf "::: (2) ping failed and pppd not running. Turn it on,\n"
		/usr/bin/wall "LTE Network is about to turn on. Save all work. network switching over in 60 seconds!"
		sleep 60
       		/usr/bin/pon
		/sbin/route del default
		/sbin/route add default ppp0
		logger "LTE Network ON: `date`"
	fi
 fi

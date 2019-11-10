###############################################################
# Network Route Switcher for LTE Rpi 
# v2.0
# email: privacywonk@privacywonk.net
# date: 2019-11-09
# Instructions:
# Edit the file below to change iface and pingip variables
# to your specific environment
#
###############################################################

#!/bin/bash

piface="eth0"           # primary WAN interface
p_gw="10.10.10.1"      # primary wan gateway
siface="ppp0"           # secondary WAN interface
pingip='8.8.8.8'        # what to ping
check_default_route=`/sbin/ip route | awk '/default/ { print $5 }'`
cdr_count=`/sbin/ip route | awk '/default/ { print $5 }' |wc -l`
piface_status=`cat /sys/class/net/"$piface"/operstate`
email_addr="update@thisaddress.com" #update this address

#Always ensure pppd is running, if it's not execute pon scripts
if [ "$(/bin/pidof pppd)" ]
then
        printf "`date` :::(0) PPPD is running."
else
        /usr/bin/pon
        printf "`date` :::(0) PPPD not running, turning on"
fi


if [ "$cdr_count" -ne 0 ] #check to see if there is at least one valid network route first....
then #test connectivity to primary wan
	printf "\nPinging "$pingip" from "$piface".\n"
	/bin/ping -I "$piface" -c 2 -q "$pingip"
		if [ "$?" -eq 0 ]; then       # if ping succeeds on primary WAN interface

			if [ "$check_default_route" = "$piface" ] #and the default route goes to primary interface
			then
					printf "`date` :::(1) Ping succeeded on "$piface" and default route is to "$piface". Exiting.\n"
					exit
			fi

			if [ "$check_default_route" = "$siface" ] #and the default route goes to secondary interface
			then #failback to primary interface
					/usr/bin/wall "LTE Network route is about to turn off. Save all work. Network switching over in 60 seconds!"
					sleep 60
					logger "LTE Network `date`: :::(2) ping succeeded on "$piface". Switching default route to "$piface"."
					#comment out line below if you dont want email
					echo "LTE Network `date`: :::(2) ping succeeded on "$piface". Switching default route to "$piface"." | mailx -s 'LTE Network' "$email_addr"
					printf "`date` :::(2) ping succeeded on "$piface". Switching default route to "$piface".\n"
					/sbin/route del default "$siface"
					/sbin/route add default gw "$p_gw" "$piface"
			fi

			if [ "$check_default_route" != "$piface" ] && [ "$check_default_route" != "$siface" ]
			then #we may have two default routes, delete the secondary as ping succeeded on primary
					/sbin/route del default "$siface"
					printf "`date` :::(3) ping succeeded on "$piface", multiple default routes detected. Switching to "$piface".\n"
			fi

		else #ping fails on primary WAN interface
			if [ "$check_default_route" = "$piface" ] #and the default route is still on primary WAN
			then #failover to secondary wan interface
					printf "`date` :::(4) ping failed on "$piface". Switching default route to "$siface".\n"
					logger "LTE Network `date`: :::(4) ping failed on "$piface". Switch default route to "siface"."
					#comment out line below if you dont want email
					echo "`date` :::(4) ping failed on "$piface". Switching default route to "$siface".\n" | mailx -s 'LTE Network' "$email_addr"
					/usr/bin/wall "LTE Network route is about to turn on. Save all work. network switching over in 60 seconds!"
					sleep 60
					/sbin/route del default "$piface"
					/sbin/route add default "$siface"
			fi

			if [ "$check_default_route" = "$siface" ] #and the default route is secondary WAN
			then
					printf "`date` :::(5) Ping failed on "$piface" and default route is to "$siface". Exiting.\n"
					exit
			fi
			if [ "$piface_status" != "up" ]
			then
					printf "`date` :::(6) Ping failed on "$piface" - interface not up. Switching to "$siface". \n"
					/sbin/route del default
					/sbin/route add default "$siface"
					logger "LTE Network `date` :::(6) Ping failed on "$piface" - interface not up. Switching to "$siface"."
					#comment out line below if you dont want email
					echo "`date` :::(6) Ping failed on "$piface" - interface not up. Switching to "$siface".\n" | mailx -s 'LTE Network' "$email_addr"
			fi

		fi

else #if no valid network routes, fail back to primary wan. If primary WAN fails on next check, it will activate the secondary WAN route
	printf "\nPinging "$pingip" from "$siface".\n"
	/bin/ping -I "$siface" -c 2 -q "$pingip"
	if [ "$?" -eq 0 ]; then
		/sbin/route del default "$piface"
		/sbin/route add default "$siface"
		printf "`date` :::(7) No default rotes but ping succeeded on "$siface". Adding default route to "$siface"."
		logger "LTE Network `date`: :::(7) Making "$siface" default route."
		echo 'LTE Network: :::(7) switching to ppp0' | mailx -s 'LTE Network' "$email_addr"
	else

		printf "`date` :::(8) ERROR - no default route, no ppp0 connectivity. Switching to primary WAN.\n"
		logger "LTE Network `date`: :::(8) No default route. Switching to primary WAN."
		/sbin/route add default gw "$p_gw" "$piface"
	fi
fi

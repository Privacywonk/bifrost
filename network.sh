###############################################################
# Network Switcher for LTE Rpi 
# v1.0
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


if [ "$cdr_count" -ne 0 ] #check to see if there is at least one valid network route first....
then #test connectivity to primary wan
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
                                        printf "::: (4) ping failed on "$piface". Switching default route to "$siface".\n"
                                        logger "LTE Network `date`: :::(4) ping failed on "$piface". Switch default route to "siface"."
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

                fi

else #if no valid network routes, fail back to primary wan. If primary WAN fails on next check, it will activate the secondary WAN route
        printf ":::(6) ERROR - no default route. Switching to primary WAN.\n"
        logger "LTE Network `date`: :::(6) No default route. Switching to primary WAN."
        /sbin/route add default gw "$p_gw" "$piface"
fi

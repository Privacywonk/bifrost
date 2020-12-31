#################################################################
# Network Route Switcher for Rpi with eth0 (wired) and ppp0 (LTE)
# v3.0
# email: privacywonk@privacywonk.net
# date: 2020-12-30
# Instructions:
# Edit the file below to change iface and pingip variables
# to your specific environment
#
#################################################################

#!/bin/bash

#INTERFACE CONFIGURATION
piface="eth0"           # primary WAN interface
p_gw="10.0.0.1"      	# primary wan gateway
siface="ppp0"           # secondary WAN interface
s_gw=$(/sbin/ifconfig ppp0 | awk '/inet/{print $2}') #get secondary WAN gateway from ifconfig (ppp0)
pingip='8.8.8.8'        # what to ping

#NOTIFICATION CONFIGURATION
quiet_mode="0" #send wall messages to users (1 = yes / 0 = no)
wait_time="1" #how long to wait in seconds before taking route actions (e.g. allow users time to react)
email_notifications="1"#send email notifications (1 = yes / 0 = no)
email_addr="your@address.tld" #update this address if you want email notifications when the network switches
declare -a services_restart=("ssh-tunnel") #array for services you want ot restart when the network switches. Add them as a space delimited list e.g. ("element1" "element2" "element3")

#DO NOT CHANGE
check_default_route=$(/sbin/ip route | awk '/default/ { print $5 }') #grabs device names tagged as default routes
cdr_count=$(/sbin/ip route | awk '/default/ { print $5 }' |wc -l) #count of default route devices
piface_status=$(cat /sys/class/net/"$piface"/operstate) #check eth0 device status

#simple function to loop through restart_services array and restart each service individually
bounce() {
        ## now loop through the above array
for i in "${services_restart[@]}"
do
   /usr/sbin/service "$i" restart
   printf "Restarting "$i"\n"
done
}


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
        printf "\n`date` :::Pinging "$pingip" from "$piface".\n"
        /bin/ping -I "$piface" -c 2 -q "$pingip" >/dev/null
                if [ "$?" -eq 0 ]; then       # if ping succeeds on primary WAN interface

                        if [ "$check_default_route" = "$piface" ] #and the default route goes to primary interface
                        then
                                        printf "`date` :::(1) Ping succeeded on "$piface" and default route is to "$piface". Exiting.\n"
                                        exit
                        fi

                        if [ "$check_default_route" = "$siface" ] #and the default route goes to secondary interface
                        then #failback to primary interface
                                        if [ "$quite_mode" -eq 0 ]
                                        then
                                                /usr/bin/wall "LTE Network route is about to turn off. Save all work. Network switching over in "$wait_time" seconds!"
                                        fi
                                        logger "LTE Network `date`: :::(2) ping succeeded on "$piface". Switching default route to "$piface"."
                                        sleep "$wait_time"
                                        printf "`date` :::(2) ping succeeded on "$piface". Switching default route to "$piface".\n"
                                        /sbin/ip r d default via "$s_gw" dev "$siface" #remove secondary interface from default route
                                        /sbin/ip r a default via "$p_gw" dev "$piface" #add primary interface as default route
                                        /sbin/ip r d "$pingip" via "$p_gw" dev "$piface" #remove test ping case from route table
										bounce
										
                                        if [ "$email_notifications" -eq 1 ]
                                        then
                                                echo "LTE Network `date`: :::(2) ping succeeded on "$piface". Switching default route back to "$piface"." | mailx -s 'LTE Network' "$email_addr"
                                        fi

                        fi

                        if [ "$check_default_route" != "$piface" ] && [ "$check_default_route" != "$siface" ]
                        then #we may have two default routes, delete the secondary as ping succeeded on primary
                                        /sbin/ip r d default via "$s_gw" dev "$siface" #remove secondary interface as default route
                                        /sbin/ip r d "$pingip" via "$p_gw" dev "$piface" #remove test ping case from route table in case its there from a previous encounter
                                        printf "`date` :::(3) ping succeeded on "$piface", multiple default routes detected. Switching to "$piface".\n"
										bounce
                        fi

                else #ping fails on primary WAN interface
                        if [ "$check_default_route" = "$piface" ] #and the default route is still on primary WAN
                        then #failover to secondary wan interface
                                        if [ "$quiet_mode" -eq 0 ]
                                        then
                                                /usr/bin/wall "LTE Network route is about to turn on. Save all work. network switching over in "$wait_time" seconds!"
                                        fi
                                        logger "LTE Network `date`: :::(4) ping failed on "$piface". Switch default route to "siface"."
                                        sleep "$wait_time"
                                        printf "`date` :::(4) ping failed on "$piface". Switching default route to "$siface".\n"

                                        /sbin/ip r d default via "$p_gw" dev "$piface" #remove primary interface as default route
                                        /sbin/ip r a default via "$s_gw" dev "$siface" #add secondary interface as default route
                                        /sbin/ip r a "$pingip" via "$p_gw" dev "$piface" #route test ip over eth0 for testing when network returns
										bounce
										
                                        if [ "$email_notifications" -eq 1 ]
                                        then
                                                echo "`date` :::(4) ping failed on "$piface". Switching default route to "$siface"." | mailx -s 'LTE Network' "$email_addr"
                                        fi

                        fi

                        if [ "$check_default_route" = "$siface" ] #and the default route is secondary WAN
                        then
                                        printf "`date` :::(5) Ping failed on "$piface" and default route is to "$siface". Exiting.\n"
                                        exit
                        fi
                        if [ "$piface_status" != "up" ] #check if the interface is up as a failure mode
                        then
                                        logger "LTE Network `date` :::(6) Ping failed on "$piface" - interface not up. Switching to "$siface"."
                                        printf "`date` :::(6) Ping failed on "$piface" - interface not up. Switching to "$siface". \n"
                                        /sbin/ip r d default via "$p_gw" dev "$piface" #remove primary interface as default route
                                        /sbin/ip r a default via "$s_gw" dev "$siface" #add secondary interface as default route
                                        /sbin/ip r a "$pingip" via "$p_gw" dev "$piface" #route test ip over eth0 for testing when network returns
										bounce

                                        if [ "$email_notifications" -eq 1 ]
                                        then
                                                echo "`date` :::(6) Ping failed on "$piface" - interface not up. Switching to "$siface"." | mailx -s 'LTE Network' "$email_addr"
                                        fi
                        fi

                fi

else #if no default network routes or multiple, fail back to primary wan. If primary WAN fails on next check, it will activate the secondary WAN route
        printf "\n`date` :::Pinging "$pingip" from "$siface".\n"
        /bin/ping -I "$siface" -c 2 -q "$pingip" >/dev/null
        if [ "$?" -eq 0 ]; then
                printf "`date` :::(7) No default rotes but ping succeeded on "$siface". Adding default route to "$siface"."
                logger "LTE Network `date`: :::(7) Making "$siface" default route."
				
                /sbin/ip r d default via "$p_gw" dev "$piface" #remove primary interface as default route
                /sbin/ip r a default via "$s_gw" dev "$siface" #remove secondary interface as default route
                /sbin/ip r a "$pingip" via "$p_gw" dev "$piface" #route test ip over eth0 for testing when network returns
				bounce

                if [ "$email_notifications" -eq 1 ]
                then
                        echo 'LTE Network: :::(7) switching to ppp0' | mailx -s 'LTE Network' "$email_addr"
                fi
        else

                printf "`date` :::(8) ERROR - no default route, no ppp0 connectivity. Switching to primary WAN.\n"
                logger "LTE Network `date`: :::(8) No default route. Switching to primary WAN."
                /sbin/ip r a default via "$p_gw" dev "$piface" #add primary interface as default route
                /sbin/ip r d "$pingip" via "$p_gw" dev "$piface" #remove test ping case from route table
				bounce
        fi
fi

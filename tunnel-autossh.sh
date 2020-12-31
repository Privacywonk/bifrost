###############################################################
# Reverse SSH Tunnel Setup Script 
# v1.0
# email: privacywonk@privacywonk.net
# date: 2019-08-30
# Instructions:
# Edit the file below to change variables to suite 
# your environment.
#
###############################################################



#!/bin/bash
createTunnel() {
#Definitions
# Originating Side = the host that runs this script that connects to a remote side and creates a tunnel back to itself
# remote side - the tunnel host.

keyFilePath="" #path to private key identity file
SSHremotePort="22" #remote side SSH service port. Normally 22, change if different
SSHTunnelPort="2222" #remote side port that the tunnel will be bound to (think high port numbers, e.g. 2222, 5555, etc.) 
SSHlocalPort="22" #port where SSH runs on the originating side (normally 22, change if different)
identity="username@host" #username and IP/host of remote side 

 # This command will create a tunnel on the remote side, bound to the remote side *localhost only* to the SSHTunnelPort.  
 # on the remote side it can be accessed by: /usr/bin/ssh -l username -p 2222 localhost (where username is a user on the originating system)
 # this will connect back to the originating side SSH service and present you with a login prompt or accept your key and log you in.

 /usr/bin/autossh -i "$keyFilePath" -p "$SSHremotePort" -N -R "$SSHTunnelPort":localhost:"$SSHlocalPort" "$identity"
  if [[ $? -eq 0 ]]; then
    echo Tunnel created successfully
  else
    echo An error occurred creating a tunnel. RC was $?
  fi
}

PROCESS_NUM=$(ps -ef |grep "2222\:localhost\:703" |wc -l)
if [ "$PROCESS_NUM" == "0" ]; then
  echo Creating new tunnel connection...
  createTunnel
  echo Tunnel already active...
fi

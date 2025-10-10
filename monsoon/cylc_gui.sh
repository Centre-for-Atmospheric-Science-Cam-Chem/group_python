#!/bin/bash

# Web user interface for viewing running suites' progress on Monsoon3.
# Run this on your local machine which you use to access Monsoon.
# Change the username in the URL to be your own Monsoon username.
# If it doesn't work, see ssh instructions at 
# https://wikis.ch.cam.ac.uk/atm/wiki/index.php/Using_Monsoon#Set_up_SSH_config_for_access_from_a_Unix-like_host. 

# Use a random port number to avoid colliding with others on the server
REMOTE_PORT=$(shuf -i 10000-65000 -n 1)
LOCAL_PORT=8888
 
echo "**************************************************************"
echo "Wait for 'ENGINE Bus STARTED' on Monsoon3, then locally go to:"
echo "   http://127.0.0.1:${LOCAL_PORT}/suites?user=firstname.lastname.ext"
echo "**************************************************************"
 
# Map remote port to local port and start GUI server process
ssh -t -L $LOCAL_PORT:localhost:$REMOTE_PORT monsooncylc "/common/hpcteam/bin/cylc review start $REMOTE_PORT"
#!/bin/sh
date=`date '+%Y%m%d'`;
cd /opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/;

alias now="date +%y/%m/%d\ %H:%M:%S"
echo "Transfer started at `now`"

send_data()
{
    echo
    echo "-------- Connecting to host $USER@$HOST for account $ACCOUNT... ----------"
    file1=$ACCOUNT'_nmerchandis'${date}.txt
    file2=$ACCOUNT'_nattributes'${date}.txt
    echo "Sending files:"
    ls -la $file1
    ls -la $file2
    ftp -n $HOST <<END_SCRIPT
    quote USER $USER
    quote PASS $PASSWD
    put $file1
    put $file2
    quit
END_SCRIPT
    echo "--------- done -----------"
}

HOST='mftp.linksynergy.com'

USER='nbridgemanA'
PASSWD='BBTcihUp'
ACCOUNT=24449
send_data

USER='outnetUS'
PASSWD='h8C6GSec'
ACCOUNT=35291
send_data

USER='MrPort'
PASSWD='IVBJL2iZ'
ACCOUNT=36592
send_data

echo "Transfer finished at `now`"
exit 0

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
    passive
    ls
    type
    put $file1
    put $file2
    ls
    quit
END_SCRIPT
    echo "--------- done -----------"
}

HOST='ftp.popshops.com'

USER='nbridgeman'
PASSWD='I8GCsYU2q'
ACCOUNT=24448
send_data

USER='outnet'
PASSWD='7n89paDUe'
ACCOUNT=35290
send_data

#USER='mrPORTER'
#PASSWD='Srt8aPpe'
#ACCOUNT=36586
#send_data

echo "Transfer finished at `now`"
exit 0
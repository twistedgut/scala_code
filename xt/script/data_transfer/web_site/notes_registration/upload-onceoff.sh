#!/bin/sh

for server in web1 web2 web0{1,2,3,4}-pr-dxi
do

   /usr/bin/scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/new/*.* \
     napuser@${server}:/opt/www/NetAPorter/pws/notes_registration/.

done



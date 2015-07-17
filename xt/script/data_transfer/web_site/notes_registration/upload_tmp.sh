#!/bin/sh

/opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/notes_gen_intl.pl
/opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/notes_gen_am.pl

for server in web1 web2
do

   /usr/bin/scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/*product_list.html \
     napuser@${server}:/opt/www/NetAPorter/pws/notes_registration/.

done



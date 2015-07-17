#!/bin/sh

/opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/notes_gen_intl.pl
/opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/notes_gen_am.pl


# DXI servers
# for server in web0{1,2,3,4}-pr-dxi
# C&W servers
for server in web0{1,2}-pr-cw
do

   /usr/bin/scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/notes8_intl_product_list.html \
     napuser@${server}:/opt/www/NetAPorter/pws/notes_registration/.

    /usr/bin/scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration/notes8_am_product_list.html \
     napuser@${server}:/opt/www/NetAPorter/pws/notes_registration/.

done



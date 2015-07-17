#!/bin/bash

# What about searching for stuff like
# /usr/bin/perl \
# /usr/bin/env perl \
# and all the other weid shebangs
hardcoded_list="/opt/xt/local-conf \
/opt/xt \
/var/data/xt_static \
/var/data \
/var/log \
/home/user \
/opt/svk-xt \
/tmp/ttcache \
\.\.\/ \
javascript:void \
/opt/www \
/usr/"
initial_result=raw_slashes.txt

working_result=remainder.txt
temp_file=temp_file.txt

# Clean stuff
ls t/logs/ |while read file; do echo ""> t/logs/$file; done
rm -rf t/tmp/0*


find lib script t \
! -path "*t/conf/apache_test_config.pm*" \
! -path "*t/conf/apache_test_config.pm*" \
! -path "*t/conf/extra.conf*" \
! -path "*t/conf/httpd.conf*" \
! -path "*t/conf/modperl_inc.pl*" \
! -path "*t/conf/modperl_startup.pl*" \
! -path "*t/htdocs/*" \
! -path "*t/logs/*" \
! -path "*t/tmp*" \
! -path "*script/*" \
! -path "t/00.write.required.t*" \
|xargs grep -nHP '(\S+\/)+' \
|perl -lne 's|(^.+?:\d+:)|$1e:|;print' \
> $initial_result

cp $initial_result $working_result

for hardcoded in $hardcoded_list
do
echo $hardcoded
# 
res_file_name=`echo $hardcoded|sed 's|[/:]|_|g;s|\.|dot|g;s|\\\||g'`
grep "$hardcoded" $working_result > ${res_file_name}.txt
grep -v "$hardcoded" $working_result > $temp_file
mv $temp_file $working_result
done

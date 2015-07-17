#!/bin/bash

find /opt/xt/deploy/xtracker/root/static/print_docs/ -not -iname invoice-* -not -iname  outpro-* -not -iname retpro-* -type f -ctime +14 -exec rm -f {} \;
exit

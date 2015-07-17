#!/bin/sh

# remove SUN reports

if [ "$1" ]
then
    rm -f /var/data/xt_static/data/maxisun/$1/*.csv
else
    echo "Please provide an output directory"
fi

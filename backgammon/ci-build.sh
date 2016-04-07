#!/bin/bash

unset errexit
set -o xtrace

# make a test specific database

export SOS_DB_NAME=sos
export SOS_DB_USER=www

if [ -z "$TEST_DB_HOSTNAME" ]; then
    export SOS_DB_HOSTNAME="localhost"
else
    export SOS_DB_HOSTNAME=$TEST_DB_HOSTNAME
fi;

export FALCON_DB_URL=jdbc:postgresql://$SOS_DB_HOSTNAME/$SOS_DB_NAME
export FALCON_DB_USER=$SOS_DB_USER

./db/refresh_j_db

./activator clean test package

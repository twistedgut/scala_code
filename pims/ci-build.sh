#!/bin/bash

unset errexit
set -o xtrace
set -e

export APP_DB_NAME="pims"

DB_METHOD="legacy" ./db/refresh_dev_db

./activator test
./activator rpm:packageBin

#!/bin/bash

# Work out dev db-name and user to use
DB_NAME=sos
DB_USER=sos

# Drop existing db
psql -U postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\""
psql -U postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\""

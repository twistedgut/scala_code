#!/bin/bash


if (which vagrant > /dev/null 2>&1); then
    vagrant up
    vagrant ssh -c "cd /vagrant/ && db/clean_db.sh"
else
    db/clean_db.sh
fi

./act "runMain nap.database.LiquibaseRunner"
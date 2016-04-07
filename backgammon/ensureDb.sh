#!/bin/bash

# If you happen to run stuff directly from your host machine but use vagrant as your mysql server shared with the world
# and what to be sure that server is up and running whenever you run 'runUnitTests.sh', 'runIntegration.sh', or
# 'validate.sh', uncomment the following line

if (which vagrant > /dev/null 2>&1); then
    echo "Running from OUTSIDE Vagrant"
    vagrant up
else
    echo "Running from INSIDE the Vagrant BOX"
fi


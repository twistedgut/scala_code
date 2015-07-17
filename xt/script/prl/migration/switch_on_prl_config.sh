#!/bin/bash

FILE=$1

if [[ -z "$FILE" ]]
then
    echo "Usage: switch_on_prl_config.sh [nap.properties file]"
    exit 1
fi

if [[ -z $(grep PRL_ROLLOUT_PHASE_DC2 "$FILE") ]]
then
    echo "Error: file $FILE does not contain config value PRL_ROLLOUT_PHASE_DC2"
    exit 3
fi

perl -pi -e 's{^(PRL_ROLLOUT_PHASE_DC2\s*).*}{$1 1}' $FILE

echo "PRL config has been switched on in file $FILE"

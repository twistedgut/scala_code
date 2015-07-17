#!/bin/bash

unset errexit
set -o xtrace

function main {

    echo "performing sanity test"
    sanity_test;

    echo "configuring xtracker for environment"
    configure_environment;

    echo "running actual migration scripts"
    run_migration_scripts;

}

function run_migration_scripts {

    ./script/prl/migration/dc2_full_to_goh_transfer.pl --load
    if [ $? -ne 0 ]; then
        echo "bad exit status from dc2_full_to_goh_transfer.pl --load"
        exit 21
    fi;

    ./script/prl/migration/dc2_full_to_goh_transfer.pl --show-join > show-join.report.txt
    if [ $? -ne 0 ]; then
        echo "bad exit status from dc2_full_to_goh_transfer.pl --show-join"
        exit 22
    fi;

    ./script/prl/migration/dc2_full_to_goh_transfer.pl --move-stock-to-goh
    if [ $? -ne 0 ]; then
        echo "bad exit status from dc2_full_to_goh_transfer.pl --move-stock-to-goh"
        exit 24
    fi;

}

function configure_environment {

    # copy and customise config file
    cp conf/nap_dev.properties .

    config_write "DC2_XTRACKER_DB_NAME" "xtracker_dc2";
    config_write "DC2_XTRACKER_DB_HOST" "$XT_DB_ADDR";
    config_write "DC2_XTRACKER_DB_USER" "postgres";
    config_write "DC2_XTRACKER_DB_PASS" "\"\"";
    config_write "NAP_HOST_TYPE" "XTDC2";

    # AMQ configs for DC2
    config_write "AMQ_DC2_MASTER" "$XT_DB_ADDR:61616";
    config_write "AMQ_DC2_SLAVE" "\"\"";
    config_write "DC2_AMQ_BROKER_HOSTNAME" "$XT_DB_ADDR";
    config_write "DC2_AMQ_BROKER_PORT" "61613";
    config_write "PRL_ROLLOUT_PHASE_DC2" "2";

    # build configuration
    perl Makefile.PL;
    make setup NAP_PROPERTIES_FILE=`pwd`/nap_dev.properties;
    source xtdc/xtdc.env
    rm -f MANIFEST
    make manifest 2>tmp/manifest-${JENKINS_TEST_UID}.log

    sudo chown -R $(whoami): tmp

}

function config_write {

    local placeholder=$1;
    local new_value=$2;

    perl -pi -e "s{^$placeholder.*$}{$placeholder         $new_value}" nap_dev.properties;
}

function sanity_test {
    echo "running sanity test";

    goh_row_count_sql="
        select
            count(*)
        from
            quantity
        where
            location_id = (select
                id
            from
                location
            where
                location='GOH PRL'
        );
    ";

    local sanity_file='./sanity_test_output'

    psql -U postgres -h $XT_DB_ADDR xtracker_dc2 -c "$goh_row_count_sql" > $sanity_file

    # exit status ensures target reachable
    if [ $? -eq 0 ];
    then
        echo "sanity test pased"
    else
        echo "sanity test failed"
        exit 33
    fi;

    echo "sanity file"
    cat $sanity_file

    # see how inventory records? script run before?
    INV_COUNT=`awk 'NR==3 { print $1 }' < $sanity_file`

    if [ "_$INV_COUNT" != "_0" ];
    then
        echo "santity test warning - quantity already present in prl_goh database or bad database"
    fi;

}

main;
exit 0

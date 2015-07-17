#!/bin/bash

# This script transfers information about stock from XTracker to Full PRL.
#
# It is done in following steps:
#   - on XT machine information about stock is exported from DB into dump files
#   - dump files are transferred to the PRL machine
#   - on the PRL machine PRL database is recreated from scratch
#   - on the PRL machine stock dump files are imported into DB
#   - XT database is patched to be aware that all stock was moved to the PRL
#
# Usage:
#
#   Please see body of "print_usage" function.
#


# get the hostname of machine with PRL
PRL_MACHINE=$1

# value of PRL_CONFIG environment variable for PRL machine,
# e.g.: "/opt/warehouse-prl/prl_setup/apps/full.yml /opt/warehouse-prl/prl_setup/envs/dave.yml /etc/prl/nap-prl-properties.yml"
PRL_CONFIG=$2

TIMESTAMP=$(date +%G%m%d_%H%M%S)

# directory where dump files are stored, it is valid for both XT and PRL machines
DUMP_DIRECTORY="/tmp/prl_migration/$TIMESTAMP"

# variables that contain info about PRL database
PRL_BLANK_DB_HOST="localhost"
PRL_BLANK_DB_SQL="/opt/warehouse-prl/prl_setup/db/blankdb.sql"
PRL_BLANK_DB_USER="postgres"
# init this with empty string as it then will be populated from PRL config
PRL_BLANK_DB_NAME=""

##################################################################
# Helper functions
##################################################################

print_usage(){
    echo "Not enough arguments were supplied. Usage:"
    echo ""
    echo "    $0 <MACHINE_WITH_PRL_APPLICATION> <STRING_WITH_PRL_CONFIG>"
    echo ""
    echo "E.g.:"
    echo ""
    echo "  ./move_stock_to_prl.sh prl-dc2ab.dave \"/opt/warehouse-prl/prl_setup/apps/full.yml /opt/warehouse-prl/prl_setup/envs/dave.yml /etc/prl/nap-prl-properties.yml\""
    echo ""
}

validate_script_parameters(){

    print_section_header "Checking if there are enough parameters to proceed..."

    # check that passed hostname is valid one and user has access to it
    if [[ -z "$PRL_MACHINE" ]]
    then
        print_usage
        exit 1
    fi

    TOKEN=$(ssh $PRL_MACHINE -t "echo test")
    if [[ ! "$TOKEN" =~ "test" ]]
    then
        echo "Cannot connect to PRL machine... Exiting."
        exit 1
    fi

    # check that PRL_CONFIG was passed and that is valide one
    if [[ -z "$PRL_CONFIG" ]]
    then
        print_usage
        exit 1
    fi

    TOKEN=$(ssh $PRL_MACHINE -t "PRL_CONFIG=\"$PRL_CONFIG\" /opt/xt/xt-perl/bin/perl -I /opt/warehouse-prl/lib/ -MNAP::PRL::Config -e 'NAP::PRL::Config->load_from_env; print qq/hello_perl/;' ")
    if [[ ! "$TOKEN" =~ "hello_perl" ]]
    then
        echo "Invalide PRL_CONFIG was provided... Exiting."
        exit 1
    fi


    # check that user has access to PRL database as POSTGRES user
    TOKEN=$(ssh $PRL_MACHINE -t "psql -U postgres -c \"select 'hello_db' as test\"")
    if [[ ! "$TOKEN" =~ "hello_db" ]]
    then
        echo "Cannot connect to PRL database as 'postgres' user... Exiting."
        exit 1
    fi


    # get PRL database name from conifg
    PRL_BLANK_DB_NAME=$(ssh $PRL_MACHINE -t "PRL_CONFIG=\"$PRL_CONFIG\" /opt/xt/xt-perl/bin/perl -I /opt/warehouse-prl/lib/ -MNAP::PRL::Config -e 'print NAP::PRL::Config->load_from_env->dbi_args->{name};' ")

    TOKEN=$(ssh $PRL_MACHINE -t "psql -U $PRL_BLANK_DB_USER -h $PRL_BLANK_DB_HOST -d $PRL_BLANK_DB_NAME -c \"select 'hello_blank_db' as test\"")

    if [[ ! "$TOKEN" =~ "hello_blank_db" ]]
    then
        echo "Cannot connect to PRL database with parameters for restoring blank DB... Exiting."
        exit 1
    fi
}

# helper function to print sections in script output
print_section_header(){
    echo ""
    echo ""
    echo "######################################################"
    echo "# $1"
    echo "######################################################"
    echo ""
}

start_xt(){

    print_section_header "Starting XT environment..."

    sudo /etc/init.d/jobqueuectl start
    sudo /etc/init.d/xt_amq_consumer_ctl start
    sudo /etc/init.d/xt start
}

stop_xt_environment(){
    print_section_header "Stopping XT environment..."

    sudo /etc/init.d/xt stop
    sudo /etc/init.d/xt_amq_consumer_ctl stop
    sudo /etc/init.d/jobqueuectl stop
}

prepare_xt_environment(){
    print_section_header "Setup directory for Dumps..."

    if [[ ! -d "$DUMP_DIRECTORY" ]]
    then
        mkdir -p $DUMP_DIRECTORY
        echo "Created new directory where all Dumps are going to be placed: $DUMP_DIRECTORY"
    fi

    if [[ ! -w "$DUMP_DIRECTORY" ]]
    then
        echo "You do not have permissions to deal with $DUMP_DIRECTORY... Exiting."

        # Starting XT environment...
        start_xt

        exit 1
    fi

    echo "Make sure permissions for $DUMP_DIRECTORY are in order"
    sudo chown xt-cron:xt $DUMP_DIRECTORY
}

dump_xt_stock(){
    print_section_header "Run XT dump script..."

    sudo -u xt-cron perl /opt/xt/deploy/xtracker/script/prl/migration/xt_data_dump.pl --dump-directory=$DUMP_DIRECTORY

    # check that all necessary files are created
    for FILE_TO_CHECK in location.csv location_migration.sql products.csv quantities.csv quantity_migration.sql
    do
        if [[ ! -e $DUMP_DIRECTORY/$FILE_TO_CHECK ]]
        then
            echo "$FILE_TO_CHECK was not created... Exiting."

            # Starting XT environment...
            start_xt

            exit 1
        fi

        if [[ ! -s $DUMP_DIRECTORY/$FILE_TO_CHECK ]]
        then
            echo "$FILE_TO_CHECK is empty which is not right!.. Exiting."

            # Starting XT environment...
            start_xt

            exit 1
        fi
    done
}

transfere_stock_dump_files_from_xt_to_prl_machine(){

    print_section_header "Move Dump files to the PRL machine"

    ssh $PRL_MACHINE -t "mkdir -p $DUMP_DIRECTORY"
    scp -r $DUMP_DIRECTORY/* "$PRL_MACHINE:$DUMP_DIRECTORY"
}

stop_prl_environment(){
    print_section_header "Stop PRL app and Consumer"

    ssh $PRL_MACHINE -t "sudo /sbin/service warehouse_app stop"
    ssh $PRL_MACHINE -t "sudo /sbin/service warehouse_consumer stop"
}

restore_blank_db_for_prl(){
    print_section_header "Restore blank DB for PRL"

    echo "Rename existing PRL database so we have backup"
    ssh $PRL_MACHINE -t "psql -U postgres -c \"alter database prl rename to prl_$TIMESTAMP\""

    echo "Restore blank PRL DB"
    ssh $PRL_MACHINE -t "cd /opt/warehouse-prl/; PRL_CONFIG=\"$PRL_CONFIG\" /opt/xt/xt-perl/bin/perl /opt/warehouse-prl/script/deploy/load_blank_db.pl --filename=$PRL_BLANK_DB_SQL --database=$PRL_BLANK_DB_NAME --host=$PRL_BLANK_DB_HOST --user=$PRL_BLANK_DB_USER "

    ssh $PRL_MACHINE -t "sudo yum reinstall prl"
}

import_dump_files_to_prl(){
    print_section_header "Import Dumps on PRL side"

    ssh $PRL_MACHINE -t "PRL_CONFIG=\"$PRL_CONFIG\" /opt/warehouse-prl/script/migration/import_xt_data.pl -e $DUMP_DIRECTORY"
}

start_prl_environment(){
    print_section_header "Start PRL app and Consumer"

    ssh $PRL_MACHINE -t "sudo /sbin/service warehouse_consumer restart"
    ssh $PRL_MACHINE -t "sudo /sbin/service warehouse_app restart"
}

update_xt_to_be_aware_that_prl_cares_about_stock(){
    print_section_header "Update XT database"

    echo ""
    echo "IMPORTANT: Don't carry on until you're happy that everything so far has gone as"
    echo "planned - after you pass this point there is no going back to a non-PRL XT"
    echo ""

    read -p "Are you sure you want to continue? (Y|N) " XT_USER_REPLY
    if [[ ! $XT_USER_REPLY =~ ^[Yy](es)?$ ]]
    then
        echo ""
        echo "See you next time!"
        echo ""

        # Starting XT environment...
        start_xt

        exit 1
    fi

    psql -U www -d xtracker_dc2 < $DUMP_DIRECTORY/quantity_migration.sql
    psql -U www -d xtracker_dc2 < $DUMP_DIRECTORY/location_migration.sql
}

##################################################################
# ACTION!!!
##################################################################

validate_script_parameters

stop_xt_environment

prepare_xt_environment

dump_xt_stock

transfere_stock_dump_files_from_xt_to_prl_machine

stop_prl_environment

restore_blank_db_for_prl

import_dump_files_to_prl

start_prl_environment

update_xt_to_be_aware_that_prl_cares_about_stock

start_xt

echo "Done!"

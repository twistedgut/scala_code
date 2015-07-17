#!/bin/sh
# This file is what jenkins used to run
# Now jenkins simply calls this script after setting some variables

test "$TEST_BLANK_DB" != "" || eval 'echo "[ERROR] TEST_BLANK_DB not set" 1>&2; exit 1;'
test "$TEST_DC_NAME" != "" || eval 'echo "[ERROR] TEST_DC_NAME not set" 1>&2; exit 1;'
test "$TEST_DB_BASENAME" != "" || eval 'echo "[ERROR] TEST_DB_BASENAME not set" 1>&2; exit 1;'
test "$TEST_EXECUTION_LIST" != "" || eval 'echo "[ERROR] TEST_EXECUTION_LIST not set" 1>&2; exit 1;'

# for running standalone we need an executor number. Jenkins has this set in the execution environment.
test "$EXECUTOR_NUMBER" != "" || export EXECUTOR_NUMBER=0;
echo "[INFO] Executor number: $EXECUTOR_NUMBER"

if [ "$TEST_BLANK_DB" == "true" ]; then
      # dc_611 prefix used for blankdb's
      export JENKINS_TEST_UID=611$EXECUTOR_NUMBER
else
      # dc_612 prefix used for realdb's
      export JENKINS_TEST_UID=612$EXECUTOR_NUMBER
fi
export APACHE_TEST_PORT=$JENKINS_TEST_UID
export XTDC_APP_LISTEN=$JENKINS_TEST_UID
export XTDC_XTRACKER_TEST_DBNAME=dc_$JENKINS_TEST_UID
export XTDC_JQ_TEST_DBNAME=jq_$JENKINS_TEST_UID
export XTDC_JQ_TEST_DSN=dbi:Pg:dbname=$XTDC_JQ_TEST_DBNAME
export PGPORT=5432
export PATH=/usr/pgsql-9.0/bin/:$PATH:/sbin

echo "[INFO] Current date/time is:" `date`

# function passed db_name. Returns 0 if db exists, 1 otherwise
db_exists () { if [ `psql -U postgres -lqt | cut -d \| -f 1 | grep -w $1 | wc -l` == 1 ]; then return 0; else return 1; fi }

# function passed db_name. Drops db cleanly
cleanly_drop_db () {
    if ( db_exists $1 )
    then
      echo "[INFO] Dropping database $1"
      # Ensure no open connections and drop db
      # NOTE: "procpid" is for Postgres 9.1 and earlier, but "pid" must be used for Postgres 9.2 and above.
      # More info: http://stackoverflow.com/a/5408501/137948
      psql -Upostgres postgres -x -c "SELECT * FROM pg_stat_activity WHERE datname='$1'"
      psql -Upostgres postgres -c "SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE datname='$1'"
      dropdb -Upostgres $1
    fi
}

mkdir -p ./tmp
perl -lane '/Requires:/ and print $F[1]' *.spec.in  | xargs yum list -q installed > ./tmp/installed_dependencies.txt

echo "[INFO] Checking for leftover test servers listening on port $XTDC_APP_LISTEN"
OLD_TEST_XTS=`sudo fuser -n tcp $XTDC_APP_LISTEN`
if [ -n "$OLD_TEST_XTS" ]; then
    echo "[WARN] Found processes listening on port $XTDC_APP_LISTEN :"
    pwdx $OLD_TEST_XTS
    fuser -kn tcp $XTDC_APP_LISTEN
fi

if [ "$TEST_BLANK_DB" == "true" ]; then
    # BlankDB only -- START
    cleanly_drop_db $XTDC_XTRACKER_TEST_DBNAME
    echo "[INFO] Creating database $XTDC_XTRACKER_TEST_DBNAME"
    createdb -Upostgres $XTDC_XTRACKER_TEST_DBNAME
    pg_dump  -Upostgres $TEST_DB_NAME | psql -o tmp/${XTDC_XTRACKER_TEST_DBNAME}_creation.log -Upostgres $XTDC_XTRACKER_TEST_DBNAME
    # BlankDB only -- END
else
    # RealDB only -- START
    # define realdb template
    export XTDC_XTRACKER_REAL_TEMPLATE_DBNAME=$TEST_DB_BASENAME
    cleanly_drop_db $XTDC_XTRACKER_TEST_DBNAME
    echo "[INFO] Creating database $XTDC_XTRACKER_TEST_DBNAME"
    createdb -Upostgres -T $XTDC_XTRACKER_REAL_TEMPLATE_DBNAME $XTDC_XTRACKER_TEST_DBNAME
    # RealDB only -- END
fi
cleanly_drop_db $XTDC_JQ_TEST_DBNAME
echo "[INFO] Creating database $XTDC_JQ_TEST_DBNAME"
createdb -Upostgres -T jobqueue_template $XTDC_JQ_TEST_DBNAME

# Copy and tweak properties
echo "[INFO] Tweaking nap.properties"
cp conf/nap_dev.properties .
#Emptydb specific stuff
perl -pi -e 's{^($ENV{TEST_DC_NAME}_XTRACKER_DB_NAME\s*).*}{$1 dc_$ENV{JENKINS_TEST_UID}}' nap_dev.properties

#Tell it which DC it is
perl -pi -e 's{^(NAP_HOST_TYPE\s*).*}{$1 XT$ENV{TEST_DC_NAME}}' nap_dev.properties

if [ -n "$PICK_SCHEDULER_VERSION" ]; then
    echo "[INFO] Setting PICK_SCHEDULER_VERSION to [$PICK_SCHEDULER_VERSION]"
    perl -pi -e 's{^(PICK_SCHEDULER_VERSION\s+).*}{$1$ENV{PICK_SCHEDULER_VERSION}}' nap_dev.properties
fi

if [ -n "$PRL_ROLLOUT_PHASE" ]; then
    echo "[INFO] Setting PRL_ROLLOUT_PHASE for all DCs to [$PRL_ROLLOUT_PHASE]"
    perl -pi -e 's{^(PRL_ROLLOUT_PHASE_DC[\d]\s+).*}{$1$ENV{PRL_ROLLOUT_PHASE}}' nap_dev.properties
fi


# The circus is in town
echo "[INFO] The circus is in town"
perl Makefile.PL
make setup NAP_PROPERTIES_FILE=`pwd`/nap_dev.properties
source xtdc/xtdc.env

# add the just-generated files to the manifest
#
# we can't re-run mkmanifest, because we now have symlinks to large
# NFS directories (product images, for example) that would take *days*
# to scan
#
# so we do it by hand. Notice that MANIFEST.SKIP won't work here
find lib_dynamic -type f >> MANIFEST

sudo chown -R $(whoami): tmp

if [ "$TEST_LAUNCH_SERVER" == "true" ]; then
    echo "[INFO] Launching xtracker test server on port $XTDC_APP_LISTEN"
    t/TEST -start
fi

set +e
echo "[INFO] Running Tests from $TEST_EXECUTION_LIST"
JUNIT_OUTPUT_FILE=junit_output.xml prove -lrmv --timer --harness=TAP::Harness::JUnit $TEST_EXECUTION_LIST
status=$?
if [ "$TEST_LAUNCH_SERVER" == "true" ]; then
    echo "[INFO] Stopping xtracker test server"
    t/TEST -stop
fi

secondary_status=$?

if [ "$TEST_BLANK_DB" == "true" ]; then
    # BlankDB only -- START
    # Dump database for archiving
    echo "[INFO] Dumping database to test_database.sql"
    pg_dump -Upostgres $XTDC_XTRACKER_TEST_DBNAME > test_database.sql
    # BlankDB only -- END
fi


exit "$status$secondary_status"


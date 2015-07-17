#!/bin/sh

# picks up and applies all db patches in FULL_RELEASE/...

# patch db function
patch_db () {

	echo "----- patching -----" >> $log_file
	for patch in $1
	do
		echo "${patch##/?*FULL_RELEASE/}"
		echo "patch file: ${patch##/?*/}" >> $log_file

		echo "+----" >> $log_file
		sudo -u $POSTGRES_CMD -f $patch 2>> $log_file >> $log_file
		echo "----+" >> $log_file
	done
	echo "----- patched -----" >> $log_file

}

usage="usage: $0 <Version Number> <Environment> <DB Host>"

if [ "$#" -lt "3" ]
then
    echo $usage
    exit 1
fi

log_file=""
db_name=""
version=$1
environment=$2
db_host=$3
psql_path=`which psql`

file_path=/opt/xt/deploy/${version}/db_schema/FULL_RELEASE
if [ ! -d "$file_path" ]; then
	echo "Can't find: $file_path"
	echo $usage
	exit 1
fi

case $environment in
	"DC1")
		db_name="xtracker"
		;;
	"DC2")
		db_name="xtracker_dc2"
		;;
	*)
		echo "Unknown Environment: $environment"
		echo "DC1 or DC2 accepted"
		echo $usage
		exit 1
		;;
esac

POSTGRES_CMD="postgres $psql_path -d $db_name -h $db_host"

echo "Connecting to DB: $db_name as user: postgres"
sudo -u $POSTGRES_CMD <<input
\q
input
if [ $? != 0 ]; then
	echo "Couldn't connect to DB: $db_name"
	exit 1
fi

# get the patch files
com_patches=`ls $file_path/Common/*.sql 2> /dev/null`
env_patches=`ls $file_path/$environment/*.sql 2> /dev/null`

if [ $(( ${#com_patches} + ${#env_patches} )) = 0 ]; then
	echo "Couldn't find any patch files in:"
	echo "$file_path/Common"
	echo "$file_path/$environment"
	exit 2
fi

log_file="/opt/xt/logs/db_release_${environment}_${version}.log"
touch $log_file
if [ $? != 0 ]; then
	echo "Couldn't create log file: $log_file"
	exit 1
fi
echo "Log file created: $log_file"

echo "Patching"

echo "##### DB Patch log file for: $environment, version: $version on `date` #####" > $log_file

# process Common patches if any
if [ ${#com_patches} -gt 0 ]; then
	echo "Common patches" >> $log_file
	echo "Todo: `ls $file_path/Common/*.sql | wc -l`" >> $log_file

	patch_db "$com_patches"
else
	echo "No Common patches found" >> $log_file
fi

# process DCx patches if any
if [ ${#env_patches} -gt 0 ]; then
	echo "$environment patches" >> $log_file
	echo "Todo: `ls $file_path/$environment/*.sql | wc -l`" >> $log_file

	patch_db "$env_patches"
else
	echo "No $environment patches found" >> $log_file
fi

echo "##### END #####" >> $log_file

echo "Finished"

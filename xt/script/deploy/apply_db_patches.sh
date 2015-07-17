#!/bin/bash

# Script to apply DB patches depending on whether we're running on live or in a dev env
# This could be improved, I'm roughly copy/pasting what we have in xt_deploy for fast prototyping

XTDC_ENV_CONF=/etc/xtdc/xtdc.env

### Main Start ###

# First check for the presence of env variables then source a file in /etc/xtdc if it exists
if [ ! -z "$RUNAS" -o ! -z "$XTDC_BASE_DIR" ]; then
    echo "Using ENV overrides from shell";
elif [ ! -f $XTDC_ENV_CONF ]; then
    echo "I'm missing some important ENV variables..."
    echo "Are you sure you sourced your env file?"
    exit 1
else
    source $XTDC_ENV_CONF
fi

# Check passed params
if [ -z $1 ]; then
    echo "We need a version, either master or 2.15.01..."
    exit 1
fi

version=$(echo "$1" |perl -ne 'print "$1" if /^((?:\d+\.)+\d+)$/')

applied_patches=0

eval $( perl -I$XTDC_BASE_DIR/lib <<EOF
use XTracker::Config::Local qw/config_var/;
use feature 'say';

say "dc_env_name="  . config_var('DistributionCentre', 'name');
say "db_name="      . config_var('Database_xtracker','db_name');
say "db_host="      . config_var('Database_xtracker','db_host');
say "db_user="      . config_var('Database_xtracker','db_user_patcher')
    if defined config_var('Database_xtracker','db_user_patcher');
say "db_pass="      . config_var('Database_xtracker','db_pass_patcher')
    if defined config_var('Database_xtracker','db_pass_patcher');
say 'patcher_dirs="' . join(' ', @{ config_var('PatcherDirs', 'folder') }) . '"';
EOF
)

if [ -z $dc_env_name ]; then
    echo "We couldn't get a DC env name from the configs.. we need either DC1 or DC2"
    exit 1
fi

# Commented out the logic that distinguishes between applying one or the latest 3 patches.

# Check if we're dealing with a master deployment or something else...
# if [ -z $version ]
# then

    base_path=${base_path:=$XTDC_BASE_DIR}

    # Some patches may not have been applied when their version was
    # deployed. Some patches are reliant on config variables that may
    # only be enabled a number of versions down the line. E.g. PRL
    # Phase 2. So we need to look back at least that many versions to
    # find now-enabled patches and apply them.

    # Get all versions that have any config dependent patches, just to
    # be sure we catch them all.
    # e.g. db_schema/9999.99/DC2-prl_phase_2
    inter_config_dir_list=`find ${base_path}/db_schema -mindepth 1 -maxdepth 2 -type d | \
               perl -ne 'm{(.+?db_schema/[0-9]*.[0-9]*)/\w+-} and print "$1\n"' | sort -n | uniq | sed "s|${base_path}/||g"| \
               perl -Mversion -e 'while(<>){/\/(\d.*)/;$d{$_}=version->new("$1.0")}print sort{$d{$a}<=>$d{$b}}keys%d'`

    # Get a few recent version numbers from which to install patches
    # e.g. db_schema/2013.21/Common
    recent_version_count=5
    inter_version_dir_list=`find ${base_path}/db_schema -mindepth 1 -maxdepth 1 -type d -name '[0-9]*.[0-9]*'|sed "s|${base_path}/||g"| \
               perl -Mversion -e 'while(<>){/\/(\d.*)/;$d{$_}=version->new("$1.0")}print sort{$d{$a}<=>$d{$b}}keys%d'| \
               tail -n $recent_version_count`
    inter_dir_list=`echo -e "$inter_config_dir_list\n$inter_version_dir_list" | sort -n | uniq`

# else
#     major_version=`echo ${version} | sed -e 's/^\(.*\..*\)\..*/\1/g'`
#     base_path=${base_path:=$XTDC_BASE_DIR}
#     inter_dir_list=db_schema/${major_version}
# fi

for inter_dir in $inter_dir_list; do # e.g. db_schema/2012.02
    echo;
    echo "#-- Version: $inter_dir"
    for dir in $patcher_dirs; do # e.g. Common, DC2, <some feature> etc
        echo "##  Environment: $inter_dir/$dir"

        if [ ! -d $base_path/$inter_dir/$dir ]; then
            echo "##  No patch directory '$base_path/$inter_dir/$dir' found, skipping."
            continue # next iteration of for loop
        fi

        echo "##  Deploying patches for $dir environment from $base_path/$dir"
        # host defaults to localhost
        db_host=${db_host:=localhost}
        # user defaults to postgres (as *.dave and dev will likely rely on
        # this for some time
        db_user=${db_user:=postgres}
        # if we have a password, pass it through as an option
        if [ -n "$db_pass" ]; then
            password_option="--password $db_pass";
        else
            password_option="";
        fi

        patcher_cmd="patcher                          \
            --database $db_name                       \
            --host $db_host                           \
            --user $db_user                           \
            ${password_option}                        \
            --paths-relative-to $base_path/$inter_dir \
            $dir"

        echo;
        echo -n "##> "; echo $patcher_cmd;
        eval $patcher_cmd

        applied_patches=$(($applied_patches + 1))
    done
done

if [[ $applied_patches -eq 0 ]]; then
    echo "WARNING: Didn't find any patches to apply in this release."
    echo "         Was this an oversight? Are the patches in place?"
    echo
    echo "Did you know you can specify version and base_path on command line?"
    echo -e "Usage:\n\tversion=2.34 base_path=~/repo/db_schema/patches $0 $*"
fi

#!/bin/echo use .
#
# useful shell functions and definitions
#

function die() {
    status=$1
    shift

    echo "$0: $*" >&2
    exit $status
}

function maybe_mkdir() {
    for dir
    do
        [ -d "$dir" ] || mkdir -p "$dir" || die 1 "Cannot create '$dir'"
        [ -d "$dir" ] || die 1 "Required directory '$dir' does not exist"
    done
}

function stabilize_file() {
    file=$1

    MAX_TRIES=42

    while [ "$MAX_TRIES" -gt 0 ]
    do
        SIZE=$(stat -c '%s' "$file" 2>/dev/null )

        [ -f "$file" ] || return 1 # it's gone, which can happen

        # we do the existence check after trying to stat it since
        # the stat will still be valid after that test passes, but
        # might not be valid if we check for existence before a stat

        if [ "$SIZE" -gt 0 ]
        then
            MTIME=$(stat -c '%Y' "$file" 2>/dev/null )
            ETIME=$(date +'%s')

            [ -f "$file" ] || return 1

            while [ $(($ETIME - $MTIME)) -lt 10 ]
            do
                sleep 3

                MTIME=$(stat -c '%Y' "$file" 2>/dev/null )
                ETIME=$(date +'%s')

                [ -f "$file" ] || return 1

                MAX_TRIES=$(($MAX_TRIES - 1))

                [ "$MAX_TRIES" -le 0 ] && return 1
            done

            # this is the only way out with success
            return 0
        else
            sleep 3
        fi

        MAX_TRIES=$(($MAX_TRIES - 1))
    done

    return 1
}


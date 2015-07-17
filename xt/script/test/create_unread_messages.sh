#!/bin/sh -
#
# CANDO-643 helper script
#
# hack to create n unread messages for user x within XT
#
# assumes Appication user ID is 1 and that we can figure
# out the postgres dbname from the hostname
#

MESSAGE_COUNT=${1:-1001}
USERNAME=${2:-$(id -un)}

datetime=$(date)
script=$(basename $0)

case "$(hostname)" in
xtdc1*) db_name=xtracker;;
xtdc2*) db_name=xtracker_dc2;;
*) db_name=$(hostname | sed -e 's/-.*//');;
esac

seq 1 "$MESSAGE_COUNT" |
  while read n
  do
cat <<EOF
INSERT
  INTO operator.message(
    subject,
    body,
    recipient_id,
    sender_id
  )
SELECT 'Synthetic message $n' AS subject,
       'Message created by $script at $datetime' AS body,
        o.id AS recipient_id,
        1 AS sender_id
  FROM operator o
 WHERE o.username = '$USERNAME'
;
EOF
  done | psql -U www -h localhost -d "$db_name"

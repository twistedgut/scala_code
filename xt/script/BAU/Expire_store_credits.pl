#!/opt/xt/xt-perl/bin/perl
use warnings;
use strict;
use DateTime;
use FindBin qw/$Bin/;
use lib "$Bin/../../lib";
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( get_database_handle );
use XTracker::Constants::FromDB qw(:channel);
my $db_name;
eval {my $tmp = $CHANNEL__NAP_INTL};
if ($@) { $db_name = "xtracker_dc2" } else { $db_name = "xtracker" }

my $dbh = get_database_handle( { name => $db_name } );
my $dt = DateTime->now;

my $today = $dt->ymd;
$dt->subtract( years => 1, days => 1 );
my $past = $dt->ymd;

my $expiry_action = "Expired $today";

my $check = "SELECT * FROM customer_credit_log WHERE action = '$expiry_action'";
my $sth = $dbh->prepare($check);$sth->execute();my $check_failed = $sth->fetch;
die "EXITING: Previous run exists for '$expiry_action'" if defined $check_failed;
 
my $sql = "
BEGIN;

INSERT INTO customer_credit_log (customer_id, change, balance, operator_id, action, date) 
    SELECT last_refund_date.customer_id, 
        -cc.credit, 
        0 AS balance, 
        1 AS operator_id, 
        '$expiry_action' AS ACTION,
        now() AS date 
    FROM customer_credit cc 
    JOIN customer c ON cc.customer_id = c.id
    JOIN currency cu ON cc.currency_id = cu.id
    LEFT JOIN ( SELECT MAX(date) AS date, ccl.customer_id
                FROM customer_credit_log ccl 
                JOIN customer_credit cc ON ccl.customer_id = cc.customer_id
                WHERE ccl.action like 'Refund%' 
                    AND cc.channel_id IN (1,2)
                GROUP BY ccl.customer_id
        ) AS last_refund_date 
        ON last_refund_date.customer_id = c.id  
        WHERE cc.customer_id IN (   SELECT customer_id
                                    FROM (  SELECT MAX(date) AS date, ccl.customer_id
                                            FROM customer_credit_log ccl
                                            JOIN customer_credit cc ON ccl.customer_id = cc.customer_id
                                            WHERE ccl.action like 'Refund%' 
                                                AND cc.channel_id IN (1,2)
                                            GROUP BY ccl.customer_id 
                                    ) AS last_credit
                                    WHERE last_credit.date <= '$past'
                                    ORDER BY date desc
                                    )  
            AND cc.credit >= 10
            AND cc.channel_id IN (1,2)
            AND c.channel_id  IN (1, 2)
    ORDER BY last_refund_date.date desc
;

UPDATE customer_credit 
SET credit=0
WHERE customer_id IN (  SELECT customer_id 
                        FROM customer_credit_log
                        WHERE action = '$expiry_action'
);

COMMIT;";

my $final = $dbh->prepare($sql);
$final->execute();

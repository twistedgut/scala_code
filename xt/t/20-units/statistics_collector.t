#!/usr/bin/env perl

use strict;
use warnings;
use FindBin::libs;

use Test::Most;

use XTracker::Database              qw( get_database_handle );
use XTracker::Database::Channel qw( get_channels );
use XTracker::Constants::FromDB     qw( :shipment_type );
use XTracker::Statistics::Collector;

# This is the function we're replacing
# - we copied if from the Old Code so we can make sure we haven't horribly
# broken anything
sub the_previous_on_credit_hold {

    my ($dbh, $type, $channels) = @_;

    my $qry  = "SELECT channel_id,COUNT(*)
                FROM orders
                WHERE order_status_id = 1
                AND id NOT IN (SELECT orders_id FROM order_flag WHERE flag_id = 45)";

    if ($type eq 'premier') {
        $qry  .= " AND id IN (SELECT orders_id FROM link_orders__shipment
                   WHERE shipment_id IN (SELECT id FROM shipment WHERE shipment_type_id = $SHIPMENT_TYPE__PREMIER))";
    }

    $qry .= " GROUP BY channel_id ";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total += $row[1];
        $results{ $channels->{$row[0]}{config_section} } = $row[1];
    }

    $results{ALL} = $total;

    return \%results;
}

sub the_previous_on_credit_check {

    my ($dbh, $type, $channels) = @_;

    my $qry  = "SELECT channel_id,COUNT(*)
                FROM orders
                WHERE order_status_id = 2
                AND id NOT IN (SELECT orders_id FROM order_flag WHERE flag_id = 45)";

    if ($type eq 'premier') {
        $qry  .= " AND id IN (SELECT orders_id FROM link_orders__shipment WHERE shipment_id IN (SELECT id FROM shipment WHERE shipment_type_id = $SHIPMENT_TYPE__PREMIER))";
    }

    $qry .= " GROUP BY channel_id ";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total += $row[1];
        $results{ $channels->{$row[0]}{config_section} } = $row[1];
    }

    $results{ALL} = $total;

    return \%results;
}



my $dbh = get_database_handle( { name => 'xtracker', type => 'readonly' } );
my $channels = get_channels( $dbh );

{
    my $previous_results =
        the_previous_on_credit_hold(
            $dbh, 'all', $channels
        );
    my $new_results =
        XTracker::Statistics::Collector::on_credit_hold(
            $dbh, 'all', $channels
        );

    is_deeply($previous_results, $new_results, 'On credit hold is correct');
}

{
    my $previous_results =
        the_previous_on_credit_check(
            $dbh, 'all', $channels
        );
    my $new_results =
        XTracker::Statistics::Collector::on_credit_check(
            $dbh, 'all', $channels
        );

    is_deeply($previous_results, $new_results, 'On credit check is correct');
}

done_testing;

#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Constants::FromDB qw(
    :reservation_status
    :variant_type
);
use XTracker::Database qw( get_database_handle get_schema_using_dbh );
use XTracker::Database::Reservation;
use XTracker::Database::Channel qw( get_web_channels );
use XTracker::WebContent::StockManagement;

use XTracker::Config::Local qw( config_var );

my $log_dir = config_var('Logging', 'xtdc_logs_dir');

# log file for output
open (my $OUT,'>',"$log_dir/log_expired_reservation.log") || warn "Cannot open log file: $!";

my $dbh_read    = get_database_handle( { name => 'xtracker', type => 'readonly' } );
my $dbh_trans   = get_database_handle( { name => 'xtracker', type => 'transaction' } );
my $schema      = get_schema_using_dbh( $dbh_trans, 'xtracker_schema' );

# get each web channel and expire reservations
my $channels = get_web_channels($dbh_read);

foreach my $channel_id ( keys %{$channels}) {

    my $stock_manager   = XTracker::WebContent::StockManagement->new_stock_manager( {
                                                                            schema      => $schema,
                                                                            channel_id  => $channel_id,
                                                                        } );

    # FIXME This private attribute should not be used directly
    # get a web handle for the channel, use Stock Manager's
    my $dbh_web = $stock_manager->_web_dbh;

    # get all expired special orders currently live from XT
    my %specials = ();

    my $qry = "SELECT r.id, r.customer_id, r.status_id, r.variant_id, v.legacy_sku, c.is_customer_number, c.first_name, c.last_name
                FROM reservation r
                JOIN variant v ON r.variant_id = v.id
                JOIN customer c ON r.customer_id = c.id
                LEFT JOIN pre_order_item poi ON poi.reservation_id = r.id
                WHERE r.date_expired < current_timestamp
                AND r.status_id = $RESERVATION_STATUS__UPLOADED
                AND poi.reservation_id IS NULL      -- Exclude Reservations for Pre-Orders
                AND r.channel_id = ?";
    my $sth = $dbh_read->prepare($qry);
    $sth->execute( $channel_id );

    while(my $row = $sth->fetchrow_hashref){
        $specials{$row->{id}} = {
            customer_id        => $row->{customer_id},
            status_id          => $row->{status_id},
            variant_id         => $row->{variant_id},
            sku                => $row->{legacy_sku},
            is_customer_number => $row->{is_customer_number},
            first_name         => $row->{first_name},
            last_name          => $row->{last_name},
            reason             => 'EXPIRED',
        };
    }

    # FIXME The private web_dbh attribute should not be used directly
    # It should probably be an API call as it's read only, if you really want you
    # could add it to the stock manager but it's mostly a write API (this is not
    # something you would do over AMQ so arguably it's not sensible to do the
    # web database version via the stock manager)

    # get all "deleted" reservations from the website
    my $del_qry = "select * from simple_reservation where status = 'DELETED' and reserved_quantity > redeemed_quantity";
    my $del_sth = $dbh_web->prepare($del_qry);
    $del_sth->execute();

    while(my $del_row = $del_sth->fetchrow_arrayref){

        my ($product_id, $size_id)  = split(/-/, $del_row->[1]);
        my $customer_number         = $del_row->[0];

        # get XT data for reservation
        my $qry = "SELECT r.id, r.customer_id, r.status_id, r.variant_id, v.legacy_sku, c.is_customer_number, c.first_name, c.last_name
                    FROM reservation r
                    JOIN variant v ON r.variant_id = v.id
                    JOIN customer c ON r.customer_id = c.id
                    LEFT JOIN pre_order_item poi ON poi.reservation_id = r.id
                    WHERE r.status_id = $RESERVATION_STATUS__UPLOADED
                    AND v.product_id = ?
                    AND v.size_id = ?
                    AND v.type_id = $VARIANT_TYPE__STOCK
                    AND c.is_customer_number = ?
                    AND poi.reservation_id IS NULL      -- Exclude Reservations for Pre-Orders
                    AND r.channel_id = ?";

        my $sth = $dbh_read->prepare($qry);
        $sth->execute( $product_id, $size_id, $customer_number, $channel_id );

        while(my $row = $sth->fetchrow_hashref){
            $specials{$row->{id}} = {
                customer_id        => $row->{customer_id},
                status_id          => $row->{status_id},
                variant_id         => $row->{variant_id},
                sku                => $row->{legacy_sku},
                is_customer_number => $row->{is_customer_number},
                first_name         => $row->{first_name},
                last_name          => $row->{last_name},
                reason             => 'DELETED',
            };
        }
    }

    # loop through expired special orders and 'expire' the bastards
    foreach my $special_order_id (keys %specials) {
        eval {
            cancel_reservation(
                $dbh_trans,
                $stock_manager,
                {
                    reservation_id  => $special_order_id,
                    status_id       => $specials{$special_order_id}{status_id},
                    variant_id      => $specials{$special_order_id}{variant_id},
                    operator_id     => 1,
                    customer_nr     => $specials{$special_order_id}{is_customer_number},
                }
            );
            $dbh_trans->commit();
            $stock_manager->commit();
        };

        if (my $error = $@) {
            $dbh_trans->rollback();
            $stock_manager->rollback();
            chomp($error);
            print "Reservation Id: $special_order_id, " . $error . "\n";
        }
        else {
            print $OUT "$special_order_id\t"
                    . "$specials{$special_order_id}{sku}\t"
                    . "$specials{$special_order_id}{variant_id}\t"
                    . "$specials{$special_order_id}{customer_id}\n";
        }
    }
    $stock_manager->disconnect();
}

close ($OUT);

$dbh_read->disconnect();
$dbh_trans->disconnect();

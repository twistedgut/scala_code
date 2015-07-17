#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Constants::FromDB qw{:order_status :shipment_status};
use XTracker::Database 'xtracker_schema';
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::EmailFunctions;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

my $schema = xtracker_schema;
my $dbh = $schema->storage->dbh;

## get held shipment which are now passed the release date
###########################################################

my $qry = "select s.id from shipment s, shipment_hold sh where s.shipment_status_id = $SHIPMENT_STATUS__HOLD and s.id = sh.shipment_id and sh.release_date < current_timestamp";
my $sth = $dbh->prepare($qry);
$sth->execute();
while ( my $row = $sth->fetchrow_hashref() ) {

    my $shipment_id = $row->{id};
    my $shipment_status_id;

    eval {
        $schema->txn_do(sub{
            ### check status of the order
            my $order_id = get_shipment_order_id( $dbh, $shipment_id );
            my $order_info = get_order_info( $dbh, $order_id );

            ### order still on credit check
            if ( grep {
                    $_ == $ORDER_STATUS__CREDIT_HOLD || $_ == $ORDER_STATUS__CREDIT_CHECK
                } $order_info->{order_status_id}
            ) {
                $shipment_status_id = $SHIPMENT_STATUS__FINANCE_HOLD;
            }
            ### set status to Processing
            else {
                $shipment_status_id = $SHIPMENT_STATUS__PROCESSING;
            }

            ### update shipment status
            update_shipment_status( $dbh, $shipment_id, $shipment_status_id, $APPLICATION_OPERATOR_ID );

            ### remove hold entry
            my $qry = "DELETE FROM shipment_hold WHERE shipment_id = ?";
            my $sth = $dbh->prepare($qry);
            $sth->execute($shipment_id);

            ### send notification emails
            send_email(
                "xtracker\@net-a-porter.com",
                "xtracker\@net-a-porter.com",
                $_,
                "Shipment released from hold",
                "\nShipment $shipment_id beyond release date, released from hold automatically\n\nxTracker"
            ) for qw/fulfilment@net-a-porter.com ben.galbraith@net-a-porter.com/;
            print "$shipment_id Released\n";
        });
    };
    if ($@) {
        print("Update on $shipment_id failed: $@\n");
    }
}

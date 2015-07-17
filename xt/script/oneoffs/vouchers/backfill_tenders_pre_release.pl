#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use Data::Dump qw(pp);
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Constants::FromDB qw{
    :order_status
    :renumeration_class
    :renumeration_type
    :shipment_status
};
use XTracker::Database;

my ( $schema ) = XTracker::Database::get_schema_and_ro_dbh('xtracker_schema');

my $rows = 500;
my $page = 1;
# Ignores test stuff and orders that already have tenders
#my $max_tender_id = $schema->resultset('Orders::Tender')
#                           ->get_column('order_id')
#                           ->max;
my $orders = $schema->resultset('Public::Orders')->search(
    { 'me.email' => { q{!=} => 'test.suite@xtracker' }, },
    { order_by => { -desc => 'me.id' },
      rows => $rows,
      page => $page,
    }
);
my $filename = 'insert_order_tenders.sql';

# Populate orders.tenders table
my $pager = $orders->pager;
my $last_page = $pager->last_page;
my $total_entries = $pager->total_entries;
print "Creating $filename for population of orders.tender table...\n";
open ( my $FH, q{+>}, $filename ) || die "Can't open file $filename: $!\n";
$FH->autoflush(1);
while ( $page <= $last_page ) {
    my @lines = ();
    my $rs = $orders->page($page++);

    while ( my $order = $rs->next ) {
        my $shipment = $order->get_standard_class_shipment;
        my ( $spent_by_card, $spent_by_store_credit );

        if ( $shipment and ( my $renumeration = $shipment->get_sales_invoice ) ) {
            $spent_by_store_credit = abs($renumeration->store_credit || 0);
            $spent_by_card = renumeration_grand_total( $renumeration );
        }

        # If there's no renumerations use values from order row
        else {
            $spent_by_store_credit = abs( $order->store_credit || 0 );
            $spent_by_card = $order->total_value
                           - (
                               abs( $order->store_credit || 0 )
                             + abs( $order->gift_credit || 0 )
                           );
        }
        #print "Populating tenders for order id @{[$order->id]}, std class shipment is @{[$shipment->id]}\n";
        my $rank = 1;
        push @lines, q{( } . join(q{, }, $order->id, $rank++, $spent_by_store_credit, $RENUMERATION_TYPE__STORE_CREDIT ) . q{ )}
            if $spent_by_store_credit >= 0.01;
        push @lines, q{( } . join(q{, }, $order->id, $rank++, $spent_by_card, $RENUMERATION_TYPE__CARD_DEBIT ) . q{ )}
            if $spent_by_card >= 0.01;
    }
    # to not overload psql new insert stmt per 500 rows. Just to be safe
    if (@lines) {
        print $FH "BEGIN;";
        print $FH "INSERT INTO orders.tender (order_id, rank, value, type_id ) VALUES\n";
        print $FH join(",\n", @lines) . ";\n";
        print $FH "COMMIT;";
    }
    if ( $total_entries ) {
        my $done = ($page-1) * $rows;
        $done = $total_entries < $done ? $total_entries : $done;
        print "Done $done of $total_entries\n";
    }
    else {
        print "No orders.tender rows to backfill\n";
    }
}
close $FH;
print "DONE!\n";

sub renumeration_grand_total {
    my ( $renumeration ) = @_;
    return $renumeration->total_value
         + $renumeration->shipping
         + ( $renumeration->misc_refund || 0 )
         - abs($renumeration->gift_credit || 0)
         - abs($renumeration->store_credit || 0)
}

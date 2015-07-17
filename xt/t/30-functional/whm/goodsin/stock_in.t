#!/usr/bin/env perl

use NAP::policy 'test';

=head1 NAME

stock_in.t - Test the Stock In page with a Purchase Order

=head1 DESCRIPTION

Submit the Stock In page for a given Purchase Order and check values were updated
correctly.

#TAGS goodsin stockin purchaseorder printer log duplication whm

=cut

use FindBin::libs;
use Test::File;

use Test::NAP::Messaging::Helpers qw(atleast);
use Test::XTracker::Data;
use Test::XTracker::Mechanize::GoodsIn;
use Test::XTracker::PrintDocs;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local 'config_var';

use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :delivery_action
    :delivery_type
);
use XTracker::PrintFunctions;

# create an amq test object and clear the queue
my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;
my $broadcast_topic_name = config_var('Producer::Stock::DetailedLevelChange','destination');

my $perms = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Goods In/Stock In',
        'Goods In/Item Count',
        'Goods In/Surplus',
        'Goods In/Quality Control',
        'Goods In/Bag And Tag',
        'Goods In/Putaway',
    ],
    $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Measurement',
    ],
};

my $flow = Test::XT::Flow->new_with_traits(
    traits => [qw/
        Test::XT::Flow::GoodsIn
        Test::XT::Flow::PrintStation
    / ],
    mech   => Test::XTracker::Mechanize::GoodsIn->new
);

$flow->login_with_permissions( { dept => 'Distribution Management', perms => $perms } );
my $schema = Test::XTracker::Data->get_schema();

# Product tests
my ($channel,$pids) = Test::XTracker::Data->grab_products( { how_many => 2 } );
my @PRODUCT_PIDS = map { $_->{pid} } @$pids;

Test::XTracker::Data->grant_permissions( 'it.god', 'Goods In', 'Stock In',
    $AUTHORISATION_LEVEL__MANAGER );

# Ensure arrival_date is null if it exists to check it's set later in the test
my $po = Test::XTracker::Data->setup_purchase_order(\@PRODUCT_PIDS, { confirmed => 1 });

make_arrival_date_null( $po, \@PRODUCT_PIDS );

$flow->task__set_printer_station(qw/GoodsIn StockIn/);

check_stock_in( $po, 10, 0 );

# If there is no packing slip then they enter 0 in the boxes - we still want to
# create delivery items for this
$po = Test::XTracker::Data->setup_purchase_order(\@PRODUCT_PIDS, { confirmed => 1 });
make_arrival_date_null( $po, \@PRODUCT_PIDS );
check_stock_in( $po, 0, 0 );

# Voucher tests
my $voucher = Test::XTracker::Data->create_voucher;

# Create a PO with the given voucher
$po = Test::XTracker::Data->setup_purchase_order([$voucher->id]);

isa_ok($po, 'XTracker::Schema::Result::Voucher::PurchaseOrder', 'PO type check')
    or die "Wrong type!";

check_stock_in( $po, 10, 1 );

done_testing;

=head2 check_stock_in

Submit the Stock In page for the given PO and check values were updated
correctly.

=cut

sub check_stock_in {
    my ( $po, $count, $is_voucher ) = @_;

    my $mech = $flow->mech;
    $mech->login_as_department('Stock Control');

    # Get stock order from purchase order
    my $stock_order = $po->stock_orders->first;
    isa_ok( $stock_order, "XTracker::Schema::Result::Public::StockOrder" );

    # Get product from stock order
    my $product = $stock_order->product;

    my $print_directory = Test::XTracker::PrintDocs->new(
        filter_regex => qr/\.(html|png)$/,
    );

    $amq->clear_destination( $broadcast_topic_name );

    note "Submit stock order";
    $flow->flow_mech__goodsin__stockin_packingslip($stock_order->id)
        ->flow_mech__goodsin__stockin_packingslip__submit({
            map { $_->variant->sku => $_->quantity } $stock_order->stock_order_items
        });

    my $variant_id = $stock_order->stock_order_items->first->variant->id;

    $amq->assert_messages({
        destination => $broadcast_topic_name,
        assert_header => superhashof({
            type => 'DetailedStockLevelChange',
        }),
        assert_body => superhashof({
            product_id => $product->id,
            variants => superbagof({
                variant_id => $variant_id,
                levels => superhashof({
                    delivered_quantity => atleast(1),
                }),
            }),
        }),
    }, 'Broadcast Stock update sent via AMQ' );

    # If the product is not a voucher, we may need to expect a measurement form
    my $num_expected_measurement_forms = (
        !$is_voucher && $product->requires_measuring
    ) ? 1 : 0;

    # Expect delivery, barcode and possibly measurement form
    my $num_expected_files = 2 + $num_expected_measurement_forms;

    my @print_dir_new_file = sort {$a->{filename} cmp $b->{filename}} $print_directory->wait_for_new_files( files => $num_expected_files );

    my $operator_id = Test::XTracker::Data->_get_operator('it.god')->id;
    my $printer_station_name = $schema->resultset('Public::OperatorPreference')->find($operator_id)->printer_station_name;

    my $printer_info = XTracker::PrinterMatrix->new->get_printer_by_name( $printer_station_name );

    my ($delivery_file) = grep { $_->file_type eq 'delivery' } @print_dir_new_file;
    is( $delivery_file->{copies}, 1, 'Correct number of copies' );

    note "Check rows were created for delivery";

    stock_order_delivery_rows_created_ok( $stock_order );

    my $delivery = $stock_order->deliveries->next;

    check_delivery_logged_ok( $delivery );
    check_delivery_files_created_ok( $delivery, \@print_dir_new_file );

    # Check arrival_date is set correctly
    is( $stock_order->product_channel->arrival_date->dmy,
        $schema->db_now->dmy,
        'arrival date is set'
    ) if $stock_order->purchase_order->is_product_po;

    $mech->recent_delivery_status_ok( $delivery, "new" );
    return;
}

=head2 check_delivery_files_created_ok

Check files related to a delivery at the stock in stage are created correctly.

=cut

sub check_delivery_files_created_ok {
    my ( $delivery, $new_files ) = @_;

    # Check barcode file is created
    my $delivery_id = $delivery->id;
    my ($barcode_file) = grep { $_->file_type eq 'barcode' } @$new_files;
    file_not_empty_ok( $barcode_file->full_path, 'barcode created' );

    # Check delivery document is created
    my ($delivery_file) = grep { $_->file_type eq 'delivery' } @$new_files;
    file_not_empty_ok( $delivery_file->full_path, 'document created' );

    my $product = $delivery->stock_order->product;
    # Check measurement form exists
    SKIP: {
        skip 'product type requires measuring', 1,
            unless ( ref $product =~ m{Public::Product$} and $product->requires_measuring );
        my ($measurementform_file) = grep { $_->file_type eq 'measurementform' } @$new_files;
        file_not_empty_ok( $measurementform_file, 'measurement form created' );
    }
    return;
}

=head2 check_delivery_logged_ok

Check the delivery is logged and the quantity matches the delivery's total
packing slip value.

=cut

sub check_delivery_logged_ok {
    my $delivery = shift;
    confess "Missing argument (delivery)" if not $delivery;
    my $log_delivery_rs = $delivery->log_deliveries->search({
        delivery_action_id => $DELIVERY_ACTION__CREATE,
        type_id            => $DELIVERY_TYPE__STOCK_ORDER,
    });
    ok( $log_delivery_rs->count == 1, 'one delivery logged' );

    # Check total packing slip is correct
    ok( $log_delivery_rs->next->quantity == $delivery->get_total_packing_slip,
        'total packing slip log correct' );
    return;
}

=head2 stock_order_delivery_rows_created_ok

Check delivery and delivery_item rows for the related stock_order are created.

=cut

sub stock_order_delivery_rows_created_ok {
    my $stock_order = shift;

    my $d = $stock_order->deliveries;
    isnt( $d, undef, "Have deliveries");
    SKIP: {
        skip "No deliveries to count" unless defined $d;
        ok( $stock_order->deliveries->count, 'stock order has deliveries (deliveries count)' );

        # Check delivery rows created
        ok( $_->delivery_items->count, 'stock order item has delivery items' )
            for $stock_order->stock_order_items->all;
    }
    return;
}

=head2 make_arrival_date_null

Set the arrival date of the given purchase order's product to null. This sub
only takes products, not vouchers.

=cut

sub make_arrival_date_null {
    my ( $po, $pids ) = @_;
    return $po->stock_orders
              ->search({'me.product_id' => $pids})
              ->related_resultset('public_product')
              ->related_resultset('product_channel')
              ->search({'product_channel.channel_id' => $po->channel_id })
              ->update({arrival_date => undef});
}

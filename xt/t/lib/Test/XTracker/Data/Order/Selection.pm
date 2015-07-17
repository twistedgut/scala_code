package Test::XTracker::Data::Order::Selection;
# TODO: Figure out why when using NAP::policy it needs 'exporter' argument
#   to enable 'setup_normal_shipment' to be exported
use NAP::policy "tt",     qw( exporter test );

use JSON::XS ();
use MooseX::Params::Validate qw/validated_list validated_hash/;
use Perl6::Export::Attrs;

use Carp 'confess';

use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :shipment_status
    :shipment_item_status
    :shipment_type
    :storage_type
    :shipment_item_returnable_state
);
use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local;
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Script::Shipment::AutoSelect;

sub setup_normal_shipment :Export {
    my (%args) = validated_hash(
        \@_,
        channel => { isa => 'XTracker::Schema::Result::Public::Channel' },
        shipment_type_id => { isa => 'Int', optional => 1, default => $SHIPMENT_TYPE__DOMESTIC },
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1, # any extra params will be passed to new_order()
    );

    # The easy way to create an order
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );
    my @flat_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 1
    });
    my $shipment = $data->new_order(
        products => \@flat_pids,
        %args, # always includes channel and shipment_type_id
    )->{shipment_object};
    note "Shipment Nr: ".$shipment->id;

    return $shipment;
}

sub do_selection :Export {
    my ($shipment) = validated_list(
        \@_,
        shipment => { isa => 'XTracker::Schema::Result::Public::Shipment' },
    );

    my $message_logger = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

    # Use auto-selection code instead of manually selecting
    note "Auto-selecting shipments";
    XTracker::Script::Shipment::AutoSelect->new->invoke(
        verbose => 1,
        shipment_ids => [ $shipment->id ],
        auto_select_shipments => 'yes', # force auto-selection
    );

    return $message_logger;
}


sub check_logs_for_normal_selection :Export {
    my ($shipment) = validated_list(
        \@_,
        shipment => { isa => 'XTracker::Schema::Result::Public::Shipment' },
    );

    # get the last print log & shipment item status log entry for Picking List for the Shipment
    my $si_prod = $shipment->shipment_items->first;

    my $schema = Test::XTracker::Data->get_schema;
    my $item_status_log_rs = $schema->resultset('Public::ShipmentItemStatusLog');

    my $si_status_log = $item_status_log_rs->search(
        { shipment_item_id => $si_prod->id },
        { order_by => 'id DESC', rows => 1 }
    )->first;
    cmp_ok( $si_status_log->shipment_item_id, '==', $si_prod->id, "Found Shipment Item Status log entry" );
    cmp_ok( $si_status_log->shipment_item_status_id,
        '==',
        $SHIPMENT_ITEM_STATUS__SELECTED,
        "(normal product) Correct Shipment Item Status logged" );
}

sub check_selection_messages :Export {
    my ($channel, $shipment, $message_logger, $vouchers_flag,
        $iws_rollout_phase, $prl_rollout_phase) = validated_list(
        \@_,
        channel => { isa => 'XTracker::Schema::Result::Public::Channel' },
        shipment => { isa => 'XTracker::Schema::Result::Public::Shipment' },
        message_logger => { isa => 'Test::XTracker::Artifacts::RAVNI' },
        vouchers_flag => { isa => 'Bool', optional => 1, default => 0 },
        iws_rollout_phase => { isa => 'Int' },
        prl_rollout_phase => { isa => 'Int', optional => 1 },
    );

    my @expected_items = $vouchers_flag
        ? (map { sku => $_->get_true_variant->sku },
            grep { not $_->is_virtual_voucher } # messages do not include virtual vouchers
            $shipment->non_canceled_items->all)
        : (map { sku => $_->get_true_variant->sku },
            $shipment->non_canceled_items->all);

    # Don't test for the RAVNI receipt if we're running with PRLs
    return if $prl_rollout_phase;

    # Test that the RAVNI receipt has appeared
    note "Waiting for RAVNI receipt";
    $message_logger->expect_messages({
        messages => [
            {
                '@type'     => 'shipment_request',
                'details'   => {
                    shipment_id => 's-' . $shipment->id,
                    channel     => $channel->name,
                    # yes, this uses a different method than the
                    # one used in the actual producer; at this
                    # stage of the shipment they must return the
                    # same set of items
                    items       => \@expected_items,
                    has_print_docs => $shipment->list_picking_print_docs($iws_rollout_phase)
                        ? JSON::XS::true : JSON::XS::false,
                },
            }
        ]
    });
}

sub setup_voucher_shipment :Export {
    my ($shipment) = validated_list(
        \@_,
        shipment => { isa => 'XTracker::Schema::Result::Public::Shipment' },
    );

    # test with vouchers
    $shipment->discard_changes;
    $shipment->update( { gift => 1 } ); # set shipment to be a gift shipment
    my $physical_voucher = Test::XTracker::Data->create_voucher( { value => 1000 } );
    my $location = Test::XTracker::Data->set_voucher_stock( { voucher => $physical_voucher, quantity => 10 } );
    my $virtual_voucher = Test::XTracker::Data->create_voucher( { value => 2000, is_physical => 0 } );
    my $si_physical_voucher = $shipment->create_related( 'shipment_items', {
        unit_price  => $physical_voucher->value,
        tax         => 0,
        duty        => 0,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
        returnable_state_id  => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
        gift_from   => 'Physical Voucher Test From',
        gift_to     => 'Physical Voucher Test To',
        gift_message=> 'Physical Voucher Test Message',
        voucher_variant_id => $physical_voucher->variant->id,
    } );
    $si_physical_voucher->create_related( 'shipment_item_status_logs', {
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
        operator_id             => $APPLICATION_OPERATOR_ID,
    } );
    # set Virtual Voucher straight to PICKED
    my $si_virtual_voucher = $shipment->create_related( 'shipment_items', {
        unit_price  => $virtual_voucher->value,
        tax         => 0,
        duty        => 0,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
        returnable_state_id  => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
        gift_from   => 'Virtual Voucher Test From',
        gift_to     => 'Virtual Voucher Test To',
        gift_message=> 'Virtual Voucher Test Message',
        voucher_variant_id => $virtual_voucher->variant->id,
    } );

    # log all statuses in between
    $si_virtual_voucher->create_related( 'shipment_item_status_logs', {
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
        operator_id             => $APPLICATION_OPERATOR_ID,
    } );
    $si_virtual_voucher->create_related( 'shipment_item_status_logs', {
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
        operator_id             => $APPLICATION_OPERATOR_ID,
    } );
    $si_virtual_voucher->create_related( 'shipment_item_status_logs', {
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
        operator_id             => $APPLICATION_OPERATOR_ID,
    } );

    return ($si_physical_voucher, $si_virtual_voucher);
}


sub check_logs_for_voucher_selection :Export {
    my ($shipment, $si_product, $si_physical_voucher, $si_virtual_voucher) = validated_list(
        \@_,
        shipment => { isa => 'XTracker::Schema::Result::Public::Shipment' },
        si_product => { isa => 'XTracker::Schema::Result::Public::ShipmentItem' },
        si_physical_voucher => { isa => 'XTracker::Schema::Result::Public::ShipmentItem' },
        si_virtual_voucher => { isa => 'XTracker::Schema::Result::Public::ShipmentItem' },
        # si = shipment item
    );

    $_->discard_changes for ($shipment, $si_product, $si_physical_voucher, $si_virtual_voucher);

    # get the last print log & shipment item status log entry for Picking List for the Shipment

    # look for normal product
    cmp_ok( $si_product->shipment_item_status_id,
        '==',
        $SHIPMENT_ITEM_STATUS__SELECTED,
        'Product: Shipment Item Status Id as expected' );

    my $schema = Test::XTracker::Data->get_schema;
    my $item_status_log_rs = $schema->resultset('Public::ShipmentItemStatusLog');

    my $si_status_log = $item_status_log_rs->search(
        { shipment_item_id => $si_product->id },
        { order_by => 'id DESC' }
    );
    cmp_ok( $si_status_log->first->shipment_item_id, '==', $si_product->id,
        "Product: Found Shipment Item Status log entry" );
    cmp_ok( $si_status_log->first->shipment_item_status_id,
        '==',
        $SHIPMENT_ITEM_STATUS__SELECTED,
        "Product: Correct Shipment Item Status logged" );


    # look for physical voucher
    $si_physical_voucher->discard_changes;
    cmp_ok( $si_physical_voucher->shipment_item_status_id,
        '==',
        $SHIPMENT_ITEM_STATUS__SELECTED,
        'Physical Voucher: Shipment Item Status Id as expected' );

    $si_status_log = $item_status_log_rs->search(
        { shipment_item_id => $si_physical_voucher->id },
        { order_by => 'id DESC' }
    );
    cmp_ok( $si_status_log->first->shipment_item_id, '==', $si_physical_voucher->id,
        "Physical Voucher: Found Shipment Item Status log entry" );
    cmp_ok( $si_status_log->first->shipment_item_status_id,
        '==',
        $SHIPMENT_ITEM_STATUS__SELECTED,
        "Physical Voucher: Correct Shipment Item Status logged" );


    # virtual voucher shouldn't be logged
    $si_virtual_voucher->discard_changes;
    cmp_ok( $si_virtual_voucher->shipment_item_status_id, '!=', $SHIPMENT_ITEM_STATUS__SELECTED,
        'Virtual Voucher: Shipment Item Status Id as expected' );
    $si_status_log = $item_status_log_rs->search(
        { shipment_item_id => $si_virtual_voucher->id },
        { order_by => 'id DESC' }
    );
    cmp_ok( $si_status_log->first->shipment_item_status_id, '!=', $SHIPMENT_ITEM_STATUS__SELECTED,
        'Virtual Voucher: Last Shipment Item Status Log for Virtual Voucher is not Selected' );

}

1;

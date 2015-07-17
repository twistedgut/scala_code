#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

selection.t - Test the selection process during fulfilment

=head1 DESCRIPTION

Test the selection process during fulfilment.

#TAGS fulfilment selection phase0 iws loops voucher printer html http dhl ups premier checkruncondition whm

=cut

use FindBin::libs;

use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_type
                                        :shipment_item_returnable_state
                                    );


use Test::XTracker::Data;

use Test::XTracker::RunCondition prl_phase => 0, export => qw( $iws_rollout_phase );


use Test::XTracker::Mechanize;
use XTracker::Config::Local             qw( :DEFAULT );
use XTracker::Config::Parameters 'sys_param';
use XTracker::Script::Shipment::AutoSelect;
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::RAVNI;
use XTracker::PrintFunctions;

use Data::Dump  qw( pp );

my $mech    = Test::XTracker::Mechanize->new;
my $schema  = Test::XTracker::Data->get_schema;
my @channels= $schema->resultset('Public::Channel')->search({'is_enabled'=>1},{ order_by => { -desc => 'id' } })->all;
my $auto_select = sys_param('fulfilment/selection/enable_auto_selection');

Test::XTracker::Data->set_department('it.god', 'Shipping');

__PACKAGE__->setup_user_perms;

$mech->do_login;

CHANNEL:
foreach my $channel ( @channels ) {

    foreach my $shipment_type_id ($SHIPMENT_TYPE__PREMIER, $SHIPMENT_TYPE__DOMESTIC) {
        note "Creating Order for Channel: ".$channel->name." (".$channel->id.")";

        # now DHL is DC2's default carrier for international deliveries need to explicitly set
        # the carrier to 'UPS' for this DC2CA test
        my $default_carrier = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );
        my $ship_account = Test::XTracker::Data->find_or_create_shipping_account( { channel_id => $channel->id, carrier => $default_carrier."%" } );

        my $address = Test::XTracker::Data->create_order_address_in(
            "current_dc_premier",
        );

        my $pids = Test::XTracker::Data->find_or_create_products({
            channel_id  => $channel->id,
            how_many    => 2,
        });
        my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

        Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );
        Test::XTracker::Data->ensure_stock( $pids->[1]{pid}, $pids->[1]{size_id}, $channel->id );

        my $base = {
            customer_id => $customer->id,
            channel_id  => $channel->id,
            shipment_type => $shipment_type_id,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id => $ship_account->id,
            invoice_address_id => $address->id,
            shipping_charge_id => 4,
        };

        my($order,$order_hash) = Test::XTracker::Data->create_db_order({
            base => $base,
            pids => $pids,
            attrs => [
                { price => 100.00 }
            ],
        });

        my $order_nr = $order->order_nr;

        my $shipment = $order->shipments->first;
        Test::XTracker::Data->toggle_shipment_validity( $shipment, 1 );

        note "Shipping Acc.: ".$ship_account->id;
        note "Order Nr: $order_nr";
        note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

        $mech->order_nr($order_nr);

        my @items   = $order->shipments->first->shipment_items->all;
        foreach my $item ( @items ) {
            $item->create_related( 'shipment_item_status_logs', {
                                            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                            operator_id             => $APPLICATION_OPERATOR_ID,
                                    } );
        }

        my ($ship_nr, $status, $category) = gather_order_info();
        note "Shipment Nr: $ship_nr";

        # The order status might be Credit Hold. Check and fix if needed
        if ($status eq "Credit Hold") {
            Test::XTracker::Data->set_department('it.god', 'Finance');
            $mech->reload;
            $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
            ($ship_nr, $status, $category) = gather_order_info();
        }
        is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

        if ($iws_rollout_phase == 0) {
            test_selection_phase0( $mech, $channel, $ship_nr, 1 );
        } else {
            test_selection( $mech, $channel, $ship_nr, 1 );
        }
    }
}

test_prioritising($mech);

done_testing;


=head2 test_selection

 $mech  = test_selection( $mech, $channel, $shipment_id, $oktodo )

This tests the selection process that prints the Picking Lists and that the printer being used is the correct one.

=cut

sub test_selection {
    my ( $mech, $channel, $ship_nr, $oktodo )       = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $dbh         = $schema->storage->dbh;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    my $item_status_log_rs  = $schema->resultset('Public::ShipmentItemStatusLog');

    my $conf_section    = $channel->business->config_section;
    my $si_prod         = $shipment->shipment_items->first;
    my @tmp;

    SKIP: {
        skip "test_selection",1         if ( !$oktodo );

        note "TESTING Selection - Regular";

        # In a few lines, the test will look at the print log. There is a race
        # condition that will stop that working. There's a nice piece of code of
        # that monitors the print docs directory in a way that gets around this
        # error condition, and we can use that to make sure we don't look at the
        # print log too early...

        {
        my $receipt_directory = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

        select_shipment($mech, $ship_nr);

        # Wait for the RAVNI receipt has appeared before going further
        note "Waiting for RAVNI receipt";
        $receipt_directory->expect_messages({
            messages => [
                {
                    '@type'     => 'shipment_request',
                    'details'   => {
                        shipment_id => 's-' . $ship_nr,
                        channel     => $channel->name,
                        # yes, this uses a different method than the
                        # one used in the actual producer; at this
                        # stage of the shipment they must return the
                        # same set of items
                        items       => [ map {sku => $_->get_true_variant->sku }, $shipment->non_canceled_items->all ],
                        has_print_docs => $shipment->list_picking_print_docs( config_var('IWS', 'rollout_phase') ) ? JSON::XS::true : JSON::XS::false,
                    },
                }
            ]
        });
        }

        # get the last print log & shipment item status log entry for Picking List for the Shipment
        $si_prod->discard_changes;


        my $si_status_log   = $item_status_log_rs->search( { shipment_item_id => $si_prod->id }, { order_by => 'id DESC', rows => 1 } )->first;
        cmp_ok( $si_status_log->shipment_item_id, '==', $si_prod->id, "Found Shipment Item Status log entry" );
        cmp_ok( $si_status_log->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, "Correct Shipment Item Status logged" );

        # reset the shipment items so we can do it again but with Vouchers with the Shipment
        $si_status_log->delete;
        $shipment->discard_changes;
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW } );

        if ( $conf_section eq "NAP" ) {
            # test with vouchers
            note "TESTING Selection with Physical & Virtual Vouchers";
            $shipment->update( { gift => 1 } );     # set shipment to be a gift shipment
            my $pvoucher    = Test::XTracker::Data->create_voucher( { value => 1000 } );       # Physical Voucher
            my $location    = Test::XTracker::Data->set_voucher_stock( { voucher => $pvoucher, quantity => 10 } );
            my $vvoucher    = Test::XTracker::Data->create_voucher( { value => 2000, is_physical => 0 } );       # Virtual Voucher
            my $si_pvouch   = $shipment->create_related( 'shipment_items', {
                                unit_price  => $pvoucher->value,
                                tax         => 0,
                                duty        => 0,
                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                returnable_state_id  => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                gift_from   => 'Phys Test From',
                                gift_to     => 'Phys Test To',
                                gift_message=> 'Phys Test Message',
                                voucher_variant_id => $pvoucher->variant->id,
                            } );
            $si_pvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );
            # set Virtual Voucher straight to PICKED
            my $si_vvouch   = $shipment->create_related( 'shipment_items', {
                                unit_price  => $vvoucher->value,
                                tax         => 0,
                                duty        => 0,
                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                returnable_state_id  => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                gift_from   => 'Virt Test From',
                                gift_to     => 'Virt Test To',
                                gift_message=> 'Virt Test Message',
                                voucher_variant_id => $vvoucher->variant->id,
                            } );

            # # log all statuses in between
            $si_vvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );
            $si_vvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );
            $si_vvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );

            select_shipment($mech, $ship_nr);

            # get the last log entries for Picking List for the Shipment
            $si_prod->discard_changes;
            $si_pvouch->discard_changes;
            $si_vvouch->discard_changes;

            # look for normal product
            cmp_ok( $si_prod->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, 'Product: Shipment Item Status Id as expected' );
            $si_status_log  = $item_status_log_rs->search( { shipment_item_id => $si_prod->id }, { order_by => 'id DESC' } );
            cmp_ok( $si_status_log->first->shipment_item_id, '==', $si_prod->id, "Product: Found Shipment Item Status log entry" );
            cmp_ok( $si_status_log->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, "Product: Correct Shipment Item Status logged" );

            # look for physical voucher
            cmp_ok( $si_pvouch->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, 'Phys Voucher: Shipment Item Status Id as expected' );
            $si_status_log  = $item_status_log_rs->search( { shipment_item_id => $si_pvouch->id }, { order_by => 'id DESC' } );
            cmp_ok( $si_status_log->first->shipment_item_id, '==', $si_pvouch->id, "Phys Voucher: Found Shipment Item Status log entry" );
            cmp_ok( $si_status_log->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, "Phys Voucher: Correct Shipment Item Status logged" );


            # virtual voucher shouldn't be logged
            cmp_ok( $si_vvouch->shipment_item_status_id, '!=', $SHIPMENT_ITEM_STATUS__SELECTED, 'Virt Voucher: Shipment Item Status Id as expected' );
            $si_status_log  = $item_status_log_rs->search( { shipment_item_id => $si_vvouch->id }, { order_by => 'id DESC' } );
            cmp_ok( $si_status_log->first->shipment_item_status_id, '!=', $SHIPMENT_ITEM_STATUS__SELECTED, 'Virt Voucher: Last Shipment Item Status Log for Virtual Voucher is not Selected' );

        }
    }

    return $mech;
}


#------------------------------------------------------------------------------------------------

sub setup_user_perms {
  Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
  # Perms needed for the order process
  for ('Airwaybill', 'Dispatch', 'Packing', 'Picking', 'Labelling', 'Invalid Shipments' ) {
    Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2);
  }
  Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', 'Selection', 3);
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}



=head2 test_selection_phase0

 $mech  = test_selection_phase0( $mech, $channel, $shipment_id, $oktodo )

This tests the selection process that prints the Picking Lists and that the printer being used is the correct one.

=cut

sub test_selection_phase0 {
    my ( $mech, $channel, $ship_nr, $oktodo )       = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $dbh         = $schema->storage->dbh;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    my $item_status_log_rs  = $schema->resultset('Public::ShipmentItemStatusLog');

    my $conf_section    = $channel->business->config_section;
    my $si_prod         = $shipment->shipment_items->first;
    my @tmp;

    my $type_of_dispatch = 'regular';
    $type_of_dispatch = 'fast' if ($shipment->shipment_type_id == $SHIPMENT_TYPE__PREMIER);
    SKIP: {
        skip "test_selection",1         if ( !$oktodo );

        note "TESTING Selection - $type_of_dispatch";

        # In a few lines, the test will look at the print log. There is a race
        # condition that will stop that working. There's a nice piece of code of
        # that monitors the print docs directory in a way that gets around this
        # error condition, and we can use that to make sure we don't look at the
        # print log too early...
        my $print_directory = Test::XTracker::PrintDocs->new();
        my $receipt_directory = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');


        select_shipment($mech, $ship_nr);

        # Wait for the RAVNI receipt has appeared before going further
        note "Waiting for RAVNI receipt";
        $receipt_directory->expect_messages({
            messages => [
                {
                    '@type'     => 'shipment_request',
                    'details'   => {
                        shipment_id => 's-' . $ship_nr,
                        channel     => $channel->name,
                        # yes, this uses a different method than the
                        # one used in the actual producer; at this
                        # stage of the shipment they must return the
                        # same set of items
                        items       => [ map {sku => $_->get_true_variant->sku }, $shipment->non_canceled_items->all ],
                        has_print_docs => $shipment->list_picking_print_docs ? JSON::XS::true : JSON::XS::false,
                    },
                }
            ]
        });
        my ($picking_sheet) = grep { $_->file_type eq 'pickinglist' }
            $print_directory->new_files();
        die "No picking sheet found" unless $picking_sheet;

        # get the last print log & shipment item status log entry for Picking List for the Shipment
        $si_prod->discard_changes;
        $print_directory->non_empty_file_exists_ok( 'pickinglist-'.$ship_nr, 'should find picking list file');
        cmp_ok( $si_prod->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, 'Shipment Item Status Id as expected' );
        my $si_status_log   = $item_status_log_rs->search( { shipment_item_id => $si_prod->id }, { order_by => 'id DESC', rows => 1 } )->first;
        cmp_ok( $si_status_log->shipment_item_id, '==', $si_prod->id, "Found Shipment Item Status log entry" );
        cmp_ok( $si_status_log->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, "Correct Shipment Item Status logged" );

        my $pickinglist_relative_path = XTracker::PrintFunctions::path_for_print_document({
            document_type => 'pickinglist',
            id => $ship_nr,
            relative => 1,
        });
        $mech->get_ok( "/print_docs/$pickinglist_relative_path" );
        @tmp    = $mech->get_table_row( $si_prod->variant->sku );       # check the contents of the file
        cmp_ok( scalar( @tmp ), '>', 0, 'Found Shipment Item Variant in Picking List File' );
        $mech->content_unlike( qr{<h1>GIFT}, "Word 'GIFT' does NOT appear in picking list" );

        # reset the shipment items so we can do it again but with Vouchers with the Shipment
        $si_status_log->delete;
        $shipment->discard_changes;
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW } );

        if ( $conf_section eq "NAP" ) {
            # test with vouchers
            note "TESTING Selection with Physical & Virtual Vouchers";
            $shipment->update( { gift => 1 } );     # set shipment to be a gift shipment
            my $pvoucher    = Test::XTracker::Data->create_voucher( { value => 1000 } );       # Physical Voucher
            my $location    = Test::XTracker::Data->set_voucher_stock( { voucher => $pvoucher, quantity => 10 } );
            my $vvoucher    = Test::XTracker::Data->create_voucher( { value => 2000, is_physical => 0 } );       # Virtual Voucher
            my $si_pvouch   = $shipment->create_related( 'shipment_items', {
                                unit_price  => $pvoucher->value,
                                tax         => 0,
                                duty        => 0,
                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                returnable_state_id  => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                gift_from   => 'Phys Test From',
                                gift_to     => 'Phys Test To',
                                gift_message=> 'Phys Test Message',
                                voucher_variant_id => $pvoucher->variant->id,
                            } );
            $si_pvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );
            # set Virtual Voucher straight to PICKED
            my $si_vvouch   = $shipment->create_related( 'shipment_items', {
                                unit_price  => $vvoucher->value,
                                tax         => 0,
                                duty        => 0,
                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                returnable_state_id  => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                gift_from   => 'Virt Test From',
                                gift_to     => 'Virt Test To',
                                gift_message=> 'Virt Test Message',
                                voucher_variant_id => $vvoucher->variant->id,
                            } );
            # log all statuses in between
            $si_vvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );
            $si_vvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );
            $si_vvouch->create_related( 'shipment_item_status_logs', {
                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                                                operator_id             => $APPLICATION_OPERATOR_ID,
                                        } );

            # Prepare for over-write of the printer sheet asset. We'll start by
            # removing the file that would be overwritten, and then, to be
            # extra safe, call new_files() to reset the watcher.
            unlink $picking_sheet->full_path ||
                die "Couldn't remove old picking sheet";
            $print_directory->new_files();
            $receipt_directory->new_files();

            select_shipment($mech, $ship_nr);

            # Wait for that picking sheet to appear before going any further...
            $receipt_directory->wait_for_new_files();
            my ($picking_sheet) = grep { $_->file_type eq 'pickinglist' }
                $print_directory->new_files();
            die "No picking sheet found" unless $picking_sheet;

            # get the last log entries for Picking List for the Shipment
            $si_prod->discard_changes;
            $si_pvouch->discard_changes;
            $si_vvouch->discard_changes;

            # check picking list file
            $print_directory->non_empty_file_exists_ok( 'pickinglist-'.$ship_nr, 'should find picking list file' );
            my $pickinglist_relative_path = XTracker::PrintFunctions::path_for_print_document({
                document_type => 'pickinglist',
                id => $ship_nr,
                relative => 1,
            });
            $mech->get_ok( "/print_docs/$pickinglist_relative_path" );
            $mech->has_tag_like( 'h1', qr/GIFT/, "Word 'GIFT' appears in picking list" );

            # look for normal product
            cmp_ok( $si_prod->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, 'Product: Shipment Item Status Id as expected' );
            $si_status_log  = $item_status_log_rs->search( { shipment_item_id => $si_prod->id }, { order_by => 'id DESC' } );
            cmp_ok( $si_status_log->first->shipment_item_id, '==', $si_prod->id, "Product: Found Shipment Item Status log entry" );
            cmp_ok( $si_status_log->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, "Product: Correct Shipment Item Status logged" );
            @tmp    = $mech->get_table_row( $si_prod->variant->sku );       # check the contents of the file
            cmp_ok( scalar( @tmp ), '>', 0, 'Product: Found Shipment Item Variant in Picking List File' );

            # look for physical voucher
            cmp_ok( $si_pvouch->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, 'Phys Voucher: Shipment Item Status Id as expected' );
            $si_status_log  = $item_status_log_rs->search( { shipment_item_id => $si_pvouch->id }, { order_by => 'id DESC' } );
            cmp_ok( $si_status_log->first->shipment_item_id, '==', $si_pvouch->id, "Phys Voucher: Found Shipment Item Status log entry" );
            cmp_ok( $si_status_log->first->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__SELECTED, "Phys Voucher: Correct Shipment Item Status logged" );
            @tmp    = $mech->get_table_row( $pvoucher->variant->sku );       # check the contents of the file
            cmp_ok( scalar( @tmp ), '>', 0, 'Phys Voucher: Found Shipment Item Variant in Picking List File' );

            # Check size is set to 'No Size' for gift vouchers only
            for ( @{ $picking_sheet->as_data->{item_list} } ) {
                if ( $_->{Designer} =~ 'Gift Card' ) {
                    is( $_->{Size}, 'No Size',
                        'Physical gift voucher size ok' );
                }
                else {
                    isnt( $_->{Size}, 'No Size',
                        'Non physical-gift-voucher has size ok' );
                }
            }

            # virtual voucher shouldn't be logged
            cmp_ok( $si_vvouch->shipment_item_status_id, '!=', $SHIPMENT_ITEM_STATUS__SELECTED, 'Virt Voucher: Shipment Item Status Id as expected' );
            $si_status_log  = $item_status_log_rs->search( { shipment_item_id => $si_vvouch->id }, { order_by => 'id DESC' } );
            cmp_ok( $si_status_log->first->shipment_item_status_id, '!=', $SHIPMENT_ITEM_STATUS__SELECTED, 'Virt Voucher: Last Shipment Item Status Log for Virtual Voucher is not Selected' );
            @tmp    = $mech->get_table_row( $vvoucher->variant->sku );       # check the contents of the file
            cmp_ok( scalar( @tmp ), '==', 0, 'Virt Voucher: NO Shipment Item Variant found in Picking List File' );
        }
    }

    return $mech;
}

sub select_shipment {
    my ($mech, $shipment_id) = @_;

    if ($auto_select) {
        note "Auto-selecting shipment $shipment_id";
        return XTracker::Script::Shipment::AutoSelect->new->invoke(
            verbose => 1,
            shipment_ids => [ $shipment_id ],
        );
    }

    note "Manually selecting shipment $shipment_id";
    $mech->get_ok( '/Fulfilment/Selection' );
    $mech->submit_form_ok( {
        form_name   => 'f_select_shipment',
        fields => {
            'selection_type'     =>'pick',
            'pick-'.$shipment_id => 1,
        },
        button      => 'submit',
    }, "Make Selection: ".$shipment_id );
    $mech->no_feedback_error_ok;
}


sub test_prioritising {
    my ($mech) = @_;

    note "Test bumping priority of a shipment";
    unless ($auto_select) {
      note "Turning on auto selection temporarily";
      sys_param('fulfilment/selection/enable_auto_selection',1);
    }

    # Run the tests in an eval so we still turn auto select off if we get an error
    eval {
        $mech->get_ok( '/Fulfilment/Selection' );
        my @selections = $mech->as_data;

        my $shipment = $selections[0]->{shipments}[1]{'Shipment Number'}{value};
        $mech->submit_form_ok( {
            form_name   => 'f_select_shipment',
            fields => {
                'selection_type'     =>'prioritise',
                'prioritise-'.$shipment => 2,
            },
            button      => 'submit',
        }, "Request prioritisation of shipment $shipment" );
        $mech->no_feedback_error_ok;

        # Ensure shipment we prioritised has moved to top of list
        @selections = $mech->as_data;
        my $shipment_again = $selections[0]->{shipments}[0]{'Shipment Number'}{value};
        is($shipment_again, $shipment, "Shipment $shipment has moved to top of list");
    };
    my $err = $@;

    unless ($auto_select) {
      note "Turning auto selection back off";
      sys_param('fulfilment/selection/enable_auto_selection',0);
    }

    if ($err) {
      die "Died in sub test_prioritising in eval: $err";
    }
}

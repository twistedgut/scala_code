#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

returns_qc.t - Process from Selection to Returns QC

=head1 DESCRIPTION

This tests the Complete process from after the Order has been created (also making
sure it has a Gift Message) through:

    * Selection
    * Picking
    * Packing
    * Adding Airway bills
    * Dispatch
    * Create Return
    * Booking in a Return
    * Returns QC

#TAGS fulfilment goodsin toobig return selection picking packing dispatch checkruncondition cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Mechanize;
use XTracker::Config::Local qw/config_var get_packing_stations/;
use XTracker::Database::Shipment qw( :carrier_automation );
use XTracker::Constants::FromDB  qw(
    :channel
    :shipment_class
    :shipment_item_status
    :shipment_status
    :shipment_type
    :shipping_charge_class
);

use XTracker::PrinterMatrix;
use XTracker::Printers;

use Test::XTracker::PrintDocs;
use Data::Dump qw( pp );
use Test::XTracker::RunCondition dc => 'DC2', export => qw($prl_rollout_phase);
use File::Spec;

my $schema = Test::XTracker::Data->get_schema();
test_returns_qc();
done_testing;

sub test_returns_qc {
    my $channel_id  = Test::XTracker::Data->channel_for_nap()->id();
    my (undef,$pids)= Test::XTracker::Data->grab_products( { channel_id => $channel_id } );
    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );
    my $auto_states = $schema->resultset('Public::Channel')->get_carrier_automation_states();

    Test::XTracker::Data->set_carrier_automation_state( $channel_id, 'On' );
    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel_id );

    my $mech = Test::XTracker::Mechanize->new;
    my $framework = Test::XT::Flow->new_with_traits( traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::PRL',
        'Test::XT::Flow::PrintStation'
        ], mech => $mech );
    Test::XTracker::Data->set_department('it.god', 'Shipping');

    __PACKAGE__->setup_user_perms;

    $mech->do_login;

    # get shipping account for Domestic UPS
    my $shipping_account= Test::XTracker::Data->find_shipping_account( {
                                                channel_id      => $channel_id,
                                                'acc_name'      => 'Domestic',
                                                'carrier'       => 'UPS',
                                              } );

    my $address = Test::XTracker::Data->create_order_address_in( 'current_dc_premier' );

    my $order_hash = {
        customer_id          => $customer->id,
        channel_id           => $channel_id,
        items                => { $pids->[0]{sku} => { price => 100.00 } },
        shipment_type        => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status      => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id  => $shipping_account->id,
        shipping_charge_id   => 4,
        email                => 'backend@net-a-porter.com',
        placed_by            => 'backend@net-a-porter.com',
        telephone            => '1-800-481-1064',
    };

    my $order = Test::XTracker::Data->create_db_order( $order_hash );
    my $order_nr = $order->order_nr;
    note sprintf( 'Shipping Acc.: %s', $shipping_account->id() );
    note sprintf( 'Order Nr     : %s', $order_nr );
    note sprintf( 'Cust Nr/Id   : %s/%s', $customer->is_customer_number(), $customer->id() );

    $mech->order_nr( $order_nr );
    my $print_directory = Test::XTracker::PrintDocs->new();
    my $print_directory_label = Test::XTracker::PrintDocs->new(
        read_directory => [
            config_var('SystemPaths', 'document_dir') . '/label',
            config_var('SystemPaths', 'document_temp_dir')
        ],
        filter_regex   => undef,                 # Watch for all files
    );

    my ( $ship_nr, $status, $category ) = gather_order_info( $order_nr, $mech );

    set_carrier_automated( Test::XTracker::Data->get_schema->storage->dbh(), $ship_nr, 1 );

    my $shipment = $schema->resultset('Public::Shipment')->find( $ship_nr );
    $shipment->update( { gift => 1, gift_message => 'This is a Gift Message' } );
    Test::XTracker::Data->ca_good_address( $shipment );
    Test::XTracker::Data->toggle_shipment_validity( $shipment, 1 );

    # The order status might be Credit Hold. Check and fix if needed
    if ( $status eq 'Credit Hold' ) {
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = gather_order_info();
    }

    is( $status, $mech->get_table_value('Order Status:'), "Order is accepted" );
    my $skus = $mech->get_order_skus();

    my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });

    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_shipment($shipment);
        Test::XTracker::Data::Order->select_shipment($shipment);
        $framework->flow_msg__prl__pick_shipment(
            shipment_id => $shipment->id,
            container => {
                $container_id => [ $pids->[0]{sku} ],
            },
        );
        $framework->flow_msg__prl__induct_shipment( shipment_id => $shipment->id );
    } else {
        # Select the order, and start the picking process
        my $picking_sheet = $framework->flow_task__fulfilment__select_shipment_return_printdoc( $shipment->id() );

        $framework->flow_mech__fulfilment__picking
            ->flow_mech__fulfilment__picking_submit( $shipment->id() );

        # Pick the items according to the pick-sheet
        for my $item ( @{ $picking_sheet->{'item_list'} } ) {
            $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $item->{'Location'} );
            $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $item->{'SKU'} );
            $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $container_id );
        }
    }


    # Select Packing Station
    $framework->mech__fulfilment__set_packing_station( $channel_id );

    # Packing
    $framework->flow_mech__fulfilment__packing->flow_mech__fulfilment__packing_submit( $ship_nr )
        ->flow_mech__fulfilment__packing_checkshipment_submit();
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $_ ) foreach ( keys %{ $skus } );
    $framework->flow_mech__fulfilment__packing_packshipment_submit_boxes( inner => 'NAP 3', outer => 'Outer 3', channel_id => $channel_id );
    $framework->flow_mech__fulfilment__packing_packshipment_complete();

    my @label_prints = $print_directory_label->new_files();
    # NOTE this test will fail when the UPS connection is down as the shipment
    # will fail carrier automation and the labels therefore won't be printed
    is( scalar( @label_prints), 2, 'Correct number of labels printed' );
    foreach my $label_print ( @label_prints ) {
        is( $label_print->printer_name(), 'pack_prn_01', 'Label - Sent to the correct printer' );
        is( $label_print->copies(),       1,             'Label - Correct number of copies' );
    }

    # Airway Bills
    set_printer_station( $framework, 'Fulfilment', 'Airwaybill', $order_hash->{channel_id} );
    my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
    $framework->flow_mech__fulfilment__airwaybill()
        ->flow_mech__fulfilment__airwaybill_shipment_id( { shipment_id => $ship_nr } )
        ->flow_mech__fulfilment__airwaybill_airwaybills( { outward => $out_awb, 'return' => $ret_awb } );

    # Dispatch
    $framework->flow_mech__fulfilment__dispatch()
        ->flow_mech__fulfilment__dispatch_shipment( $ship_nr );

    # Create Return
    my $products = [ map { { sku => $_, selected => 1, return_reason => 'Price' }; } keys %{ $skus } ];
    $framework->flow_mech__customercare__orderview( $order->id() )
        ->flow_mech__customercare__view_returns()
        ->flow_mech__customercare__view_returns_create_return()
        ->flow_mech__customercare__view_returns_create_return_data( { products => $products } )
        ->flow_mech__customercare__view_returns_create_return_submit( { send_email => 'no' } );

    ok( scalar( $print_directory->new_files() ), 'Cleaned up print logs' );

    # Set Printer Station for ReturnsIn
    set_printer_station( $framework, 'GoodsIn', 'ReturnsIn', $order_hash->{channel_id} );

    # Returns In
    $framework->flow_mech__goodsin__returns_in->flow_mech__goodsin__returns_in_submit( $ret_awb );
    $framework->flow_mech__goodsin__returns_in__book_in( $_ ) foreach ( keys %{ $skus } );
    $framework->flow_mech__goodsin__returns_in__complete_book_in();

    my @print_files = $print_directory->wait_for_new_files( files => 1 );
    my $operator = $schema->resultset('Public::Operator')->find({username => 'it.god'});
    foreach my $print_file ( @print_files ) {
        is( $print_file->{copies},    1,           'Correct number of copies' );
        is( $print_file->{file_type}, 'returndel', 'Correct file type' );

        my $location = XTracker::Printers->new->location(
            $operator->discard_changes->operator_preference->printer_station_name
        );

        is(
            $print_file->{printer_name},
            $location->printer_for_type('document')->lp_name,
            'Correct printer'
        );
    }

    # Find all return delivery ids based on the shipment number
    my @delivery_ids = ();
    my $returns = $schema->resultset('Public::Return')->search( { shipment_id => $shipment->id() } );
    while( my $return = $returns->next() ) {
        my $links_d_r = $return->link_delivery__returns();
        while( my $link_d_r = $links_d_r->next() ) {
            push @delivery_ids, $link_d_r->delivery_id();
        }
    }

    # Set Printer Station for ReturnsQC
    set_printer_station( $framework, 'GoodsIn', 'ReturnsQC', $order_hash->{channel_id} );

    # Returns QC for all deliveries
    foreach my $delivery_id ( @delivery_ids ) {
        $framework->flow_mech__goodsin__returns_qc()
            ->flow_mech__goodsin__returns_qc_submit( $delivery_id )
            ->flow_mech__goodsin__returns_qc__process();
    }

    @label_prints = $print_directory_label->wait_for_new_files( files => 1 );

    foreach my $label_print ( @label_prints ) {
        is( $label_print->{copies}, 1, 'Label - Correct number of copies' );

        my $location = XTracker::Printers->new->location(
            $operator->discard_changes->operator_preference->printer_station_name
        );

        is(
            $label_print->{printer_name},
            $location->printer_for_type('small_label')->lp_name,
            'Label - Correct printer'
        );
    }

    return 1;
}

sub get_printer_info_for_operator {
    my ( $operator, $setting ) = @_;

    return XTracker::PrinterMatrix
        ->new({schema => $schema})
        ->get_printer($operator->discard_changes->operator_preference,$setting);
}

sub set_printer_station {
    my ( $framework, $section, $subsection, $channel_id ) = @_;

    $framework->flow_mech__select_printer_station( {
        section    => $section,
        subsection => $subsection,
        channel_id => $channel_id,
    } );

    $framework->flow_mech__select_printer_station_submit;

    return;
}

sub setup_user_perms {
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Customer Search', 2);
    # Perms needed for the order process
    for (qw/Airwaybill Dispatch Packing Picking Selection Labelling Manifest/ ) {
        Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', $_, 2 );
    }
    Test::XTracker::Data->grant_permissions( 'it.god', 'Goods In', 'Returns In', 2 );
    Test::XTracker::Data->grant_permissions( 'it.god', 'Goods In', 'Returns QC', 2 );
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
    my ( $order_nr, $mech ) = @_;

    $mech->get_ok($mech->order_view_url);

    # On the order view page we need to find the shipment ID

    my $ship_nr = $mech->get_table_value('Shipment Number:');
    my $status = $mech->get_table_value('Order Status:');


    my $category = $mech->get_table_value('Customer Category:');
    return ($ship_nr, $status, $category);
}

package Test::NAP::CarrierAutomation;

=head1 NAME

Test::NAP::CarrierAutomation - Test Carrier Automation

=head1 DESCRIPTION

Test Carrier Automation

#TAGS packing checkruncondition prl loops printer ups dhl poorcoverage

=head1 SEE ALSO

Test::NAP::MoreCarrierAutomation

=head1 METHODS

=cut

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';
use Test::XTracker::RunCondition dc => 'DC2', export => qw($prl_rollout_phase);

use Data::Dump qw( pp );
use FindBin::libs;


use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::PrintDocs;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB  qw(
    :authorisation_level
    :shipment_item_status
    :shipment_status
    :shipment_type
);
use XTracker::Database::Shipment;


sub startup : Test(startup) {
    my ( $self ) = @_;

    my $channel = $self->{channel} = Test::XTracker::Data->channel_for_nap;

    Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'On' );

    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => ['Test::XT::Flow::Fulfilment', 'Test::XT::Flow::PRL']
    );

    $self->{flow}->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Customer Care/Order Search',
                'Fulfilment/Airwaybill',
                'Fulfilment/Dispatch',
                'Fulfilment/Packing',
                'Fulfilment/Picking',
                'Fulfilment/Selection',
                'Fulfilment/Labelling',
                'Fulfilment/Manifest',
            ],
        },
        dept => 'Shipping',
    });

    # Get some reusable objects
    $self->{customer} = Test::XTracker::Data->find_customer({ channel_id => $channel->id });
    $self->{pids} = (Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
        how_many => 1,
        phys_vouchers => {
            how_many => 1,
            want_stock => 10,
        },
        virt_vouchers => {
            how_many => 1,
        },
        force_create => 1, # true
    }))[1];

    # get shipping account for Domestic UPS
    $self->{shipping_account} = Test::XTracker::Data->find_shipping_account({
        channel_id      => $channel->id,
        'acc_name'      => 'Domestic',
        'carrier'       => 'UPS',
    });

    $self->SUPER::startup;
}

sub setup : Test(setup) {
    my ( $self ) = @_;

    # This is because if the order's on hold the department is set to 'Finance' :(
    Test::XTracker::Data->set_department('it.god', 'Shipping');

    $self->SUPER::setup;
}

=head2 test_are_shipments_autoable

=cut

sub test_are_shipments_autoable : Tests {
    my ( $self ) = @_;

    my @scenarios = (
        [ [$self->{pids}[0]], 'UPS', 'United States', 'product', 1 ],
        [ [$self->{pids}[1]], 'UPS', 'United States', 'physical voucher', 1 ],
        [ [$self->{pids}[2]], 'UPS', 'United States', 'virtual voucher', 0 ],
        [ [@{$self->{pids}}[0,1]], 'UPS', 'United States', 'product and physical voucher', 1 ],
        [ [@{$self->{pids}}[0,2]], 'UPS', 'United States', 'product and virtual voucher', 1 ],
    );
    for ( @scenarios ) {
        my ( $pids, $carrier, $country, $order_contents, $expected_pass ) = @$_;

        # Create order with the appropriate shipping account
        my $shipping_account = Test::XTracker::Data->find_shipping_account({
            channel_id => $self->{channel}->id,
            acc_name   => 'Domestic',
            carrier    => $carrier,
        });

        my $order = $self->create_order( $pids, $shipping_account->id );

        # Set a valid shipping address and set the country
        my $shipment = $order->get_standard_class_shipment;
        Test::XTracker::Data->ca_good_address( $shipment );
        $shipment->shipment_address->update({country => $country});

        my $is_autoable = XTracker::Database::Shipment::autoable(
            Test::XTracker::Data->get_schema, {
                shipment_id => $shipment->id,
                mode => 'isit',
                operator_id => $APPLICATION_OPERATOR_ID,
            }
        );
        ok( $expected_pass ? $is_autoable : !$is_autoable,
            sprintf(
                join( q{ },
                    'shipment %d',
                    "to $country",
                    "with $carrier",
                    "containing $order_contents",
                    'is %sautoable',
                ),
                $shipment->id,
                ( $expected_pass ? q{} : 'not ' ),
            ),
        );
    }
}

=head2 test_pass_ca_with_gift_message

=cut

sub test_pass_ca_with_gift_message : Tests {
    my ( $self ) = @_;

    my $order = $self->create_order( [$self->{pids}[0]] );

    my $shipment = $order->get_standard_class_shipment;
    $shipment->update( { gift => 1, gift_message => 'This is a Gift Message' } );

    $self->pass_carrier_automation( $shipment );
}

=head2 test_pass_ca

=cut

sub test_pass_ca : Tests {
    my ( $self ) = @_;

    my $order = $self->create_order( [$self->{pids}[0]] );

    $self->pass_carrier_automation( $order->get_standard_class_shipment );
}

=head2 test_fail_ca

=cut

sub test_fail_ca : Tests {
    my ( $self ) = @_;

    my $order = $self->create_order( [$self->{pids}[0]] );

    $self->fail_carrier_automation( $order->get_standard_class_shipment );
}

sub create_order {
    my ( $self, $pids, $shipping_account_id ) = @_;

    my ($order) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => {
            channel_id           => $self->{channel}->id,
            customer_id          => $self->{customer}->id,
            shipment_type        => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status      => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id  => $shipping_account_id // $self->{shipping_account}->id,
            shipping_charge_id   => 4,
        },
    });
    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );

    # This sets av_quality rating to 100 for DC2 - some CA related value
    my $shipment = $order->get_standard_class_shipment;
    Test::XTracker::Data->toggle_shipment_validity( $shipment, 1 );

    # Allocate in PRL(s) if applicable
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_shipment($shipment);
    }

    return $order;
}

sub pass_carrier_automation {
    my ( $self, $shipment ) = @_;
    Test::XTracker::Data->ca_good_address( $shipment );
    return $self->test_carrier_automation($shipment);
}

sub fail_carrier_automation {
    my ( $self, $shipment ) = @_;
    Test::XTracker::Data->ca_bad_address( $shipment );
    return $self->test_carrier_automation($shipment, 1);
}

sub test_carrier_automation {
    my ( $self, $shipment, $induce_fail ) = @_;

    $shipment->set_carrier_automated(1);

    my $wait_for_files;
    $induce_fail ? ($wait_for_files = 1) : ($wait_for_files = 2);

    # print gift message warnings only when we can't automate real physical
    # gift messages (which come out at the pick station)
    if (!$shipment->can_automate_gift_message()) {
        my $gift_messages = $shipment->get_gift_messages();
        my $gm_messages_count = scalar(@$gift_messages);
        $wait_for_files += $gm_messages_count;
    }

    my $print_directory = Test::XTracker::PrintDocs->new;
    $self->pack_shipment($shipment);

    my @files = map {
        $_->file_type
    } $print_directory->wait_for_new_files( files => $wait_for_files );

    is( scalar( @files ), $wait_for_files, sprintf( '%s documents printed', $wait_for_files ) );

    return;
}

sub pack_shipment {
    my ( $self, $shipment ) = @_;

    my $flow = $self->{flow};
    my $mech = $flow->mech;

    my $channel_id = $self->{channel}->id;

    my $order = $shipment->order;
    my $order_nr = $order->order_nr;
    $mech->order_nr($order_nr);

    # The order status might be Credit Hold. Check and fix if needed
    if ($order->is_on_credit_hold) {
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
    }

    ok( $order->discard_changes->is_accepted,
        sprintf( q{Order %d 'Accepted'}, $order->id ) );

    # Selection
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->select_order($order);
    } else {
        $mech   = $mech->test_direct_select_shipment( $shipment->id );
    }
    $mech   = $mech->test_edit_shipment( $shipment->id );
    $mech->has_tag('h3','Shipment Carrier Automation','Has Carrier Automation Heading');

    # Picking
    my $skus = $mech->get_order_skus;
    if ($prl_rollout_phase) {
        my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
        $flow->flow_msg__prl__pick_shipment(
            shipment_id => $shipment->id,
            container => {
                $container_id => [keys %$skus],
            }
        );
        $flow->flow_msg__prl__induct_shipment( shipment_id => $shipment->id );
    } else {
        my $print_directory = Test::XTracker::PrintDocs->new;
        $skus = $mech->get_info_from_picklist($print_directory, $skus);
        $mech->test_pick_shipment( $shipment->id, $skus );
    }

    # Select Packing Station
    $flow->mech__fulfilment__set_packing_station( $channel_id );

    # Packing
    $flow->flow_mech__fulfilment__packing
         ->flow_mech__fulfilment__packing_submit( $shipment->id )
         ->flow_mech__fulfilment__packing_checkshipment_submit();
    $flow->flow_mech__fulfilment__packing_packshipment_submit_sku( $_ )
        for ( keys %{ $skus } );
    $flow->flow_mech__fulfilment__packing_packshipment_submit_boxes(
        inner => 'NAP 3', outer => 'Outer 3', channel_id => $channel_id
    );
    $flow->flow_mech__fulfilment__packing_packshipment_complete;
}

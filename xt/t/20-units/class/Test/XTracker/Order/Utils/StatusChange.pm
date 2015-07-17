package Test::XTracker::Order::Utils::StatusChange;

use NAP::policy "tt", 'test', 'class';

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};

use Test::XTracker::Data;
use XTracker::Order::Utils::StatusChange;
use XTracker::Config::Local qw/config_var/;
use XTracker::Database::Order qw/get_order_info/;
use XTracker::Database::Shipment qw/get_order_shipment_info/;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/:shipment_status
                                   :order_status/;

sub db : Test(startup) {
    my $self = shift;
    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{dbh} = $self->{schema}->storage->dbh;
}

sub utils : Test(startup) {
    my $self = shift;
    $self->{utils} = XTracker::Order::Utils::StatusChange->new({schema => $self->{schema}});
}

sub create_order : Test(setup => 9) {
    my $self = shift;

    my $channel_id = Test::XTracker::Data->channel_for_nap->id;
    my $customer
      = Test::XTracker::Data->find_customer({channel_id => $channel_id});

    my $shipping_account
      = Test::XTracker::Data->find_shipping_account(
            { channel_id  => $channel_id,
              acc_name    => 'Domestic',
              carrier     => config_var('DistributionCentre','default_carrier') });

    my ($channel, $pids)
      = Test::XTracker::Data->grab_products({how_many => 1});

    # for each pid make sure there's stock
    foreach my $item (@{$pids}) {
        Test::XTracker::Data->ensure_variants_stock($item->{pid});
    }

    my $addr_location = Test::XTracker::Data->whatami eq 'DC1' ? 'US' : 'UK';
    my $order = Test::XTracker::Data->create_domestic_order(
        channel => Test::XTracker::Data->channel_for_nap,
        pids => $pids,
        order_address => $addr_location);

    $self->{order} = $order;
}

sub update_shipments : Tests {
    my $self = shift;

    my $shipment_ref = get_order_shipment_info( $self->{dbh}, $self->{order}->id );

    # All shipments
    my $shipment = $self->{order}->shipments->first;

    # Select a shipment item to fire the IWS message
    my $one_shipment_item = $shipment->shipment_items->first;
    $one_shipment_item->set_selected($APPLICATION_OPERATOR_ID);
    ok($shipment->does_iws_know_about_me, 'IWS knows about the shipment');

    # Do the status update and refresh the DBIC shipment
    $self->{utils}->update_shipments_status($shipment_ref, $SHIPMENT_STATUS__FINANCE_HOLD, $APPLICATION_OPERATOR_ID);
    $shipment->discard_changes;

    # Check status update
    ok($shipment->is_on_finance_hold,
       'Shipment ' . $shipment->id . ' is on finance hold');

    # Check log entry
    my $latest_log
      = $shipment->shipment_status_logs
                 ->search(undef, { order_by => { -desc => 'id' }})
                 ->first;

    is($latest_log->shipment_status_id, $SHIPMENT_STATUS__FINANCE_HOLD,
       'Latest log entry is finance hold change');

}


sub accept_order : Tests {
    my $self = shift;

    my $order_ref = get_order_info($self->{dbh}, $self->{order}->id);
    my $shipment_ref = get_order_shipment_info( $self->{dbh}, $self->{order}->id );

    $self->{utils}->change_order_status($self->{order}->id,
                                        $ORDER_STATUS__ACCEPTED,
                                        $APPLICATION_OPERATOR_ID);

    $self->{utils}->accept_order($order_ref,
                                 $shipment_ref,
                                 $self->{order}->id,
                                 $APPLICATION_OPERATOR_ID);

    my $shipment = $self->{order}->shipments->first;

    # Check order status update
    ok($self->{order}->is_accepted,
       'Order ' . $self->{order}->id . ' is accepted');

    # Check status update
    ok($shipment->is_processing,
       'Shipment ' . $shipment->id . ' is processing');
}

sub test_change_status_on_cancelled_order : Tests {
    my $self = shift;

    $self->{utils}->change_order_status($self->{order}->id,
                                        $ORDER_STATUS__CANCELLED,
                                        $APPLICATION_OPERATOR_ID);

    cmp_ok( $self->{order}->discard_changes->order_status_id,
            '==',
            $ORDER_STATUS__CANCELLED,
            'The order status is CANCELLED'
          );

    throws_ok( sub {
            $self->{utils}->change_order_status( $self->{order}->id,
                                                 $ORDER_STATUS__ACCEPTED,
                                                 $APPLICATION_OPERATOR_ID);
        },
        qr/Cannot change the status of order id .* with current status of CANCELLED/,
        'Dies with correct error when trying to change status of Cancelled order'
    );

}

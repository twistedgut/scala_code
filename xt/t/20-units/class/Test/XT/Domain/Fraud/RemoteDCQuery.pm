package Test::XT::Domain::Fraud::RemoteDCQuery;

use FindBin::libs;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

use Test::XTracker::Data;
use Test::XTracker::Mock::DHL::XMLRequest;
use XTracker::Database::Shipment qw/get_order_shipment_info/;
use XTracker::Constants qw/:application/;
use XTracker::Constants::FromDB qw/:flag :order_status :shipment_status/;
use XTracker::Config::Local qw/config_var/;
use XTracker::Logfile qw/xt_logger/;
use XT::Domain::Fraud::RemoteDCQuery;
use XTracker::Order::Utils::StatusChange;

use Test::MockModule;

sub db : Test(startup) {
    my $self = shift;
    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{dbh} = $self->{schema}->storage->dbh;
    $self->{status_change}
      = XTracker::Order::Utils::StatusChange->new({schema => $self->{schema}});
    $self->{rdc}
      = XT::Domain::Fraud::RemoteDCQuery->new({schema => $self->{schema}});
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

    my $order = Test::XTracker::Data->create_domestic_order(
                  channel => Test::XTracker::Data->channel_for_nap,
                  pids => $pids);

    ok( ($self->{order} = $order), 'created order ' . $order->id );
}


sub ask : Tests {
    my $self = shift;

    # Set the account urn
    my $customer = $self->{order}->customer;
    $customer->update({account_urn => 'urn:nap:account:test'});

    # Dispatch the question
    my $rdc = XT::Domain::Fraud::RemoteDCQuery->new({schema => $self->{schema}});

    lives_ok {$rdc->ask('CustomerHasGenuineOrderHistory?', $self->{order}->id)}
             'Remote DC message sent';

    my $query_ref = $self->schema->resultset('Public::RemoteDcQuery')
                                 ->find({orders_id => $self->{order}->id});

    ok($query_ref, 'Query reference created');
    is($query_ref->orders_id, $self->{order}->id, 'Order id is correct');
    is($query_ref->query_type, 'CustomerHasGenuineOrderHistory?',
       'Query type is correct');
}

sub test_release_order_from_credit_hold : Tests {
    my $self = shift;

    # set up the mocked call to DHL to retrieve shipment validate XML response
    my $dhl_label_type = 'dhl_routing';
    my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
        data => [
            { dhl_label => $dhl_label_type },
        ]
    );
    my $xmlreq = Test::MockModule->new( 'XTracker::DHL::XMLRequest' );
    $xmlreq->mock( send_xml_request => sub { $mock_data->$dhl_label_type } );

    # Put order on credit hold
    my $order = $self->{order};
    $self->{status_change}->change_order_status(
        $order->id, $ORDER_STATUS__CREDIT_HOLD, $APPLICATION_OPERATOR_ID
    );

    my $shipments_ref = get_order_shipment_info( $self->dbh, $order->id);

    $self->{status_change}->update_shipments_status(
        $shipments_ref,
        $SHIPMENT_STATUS__FINANCE_HOLD,
        $APPLICATION_OPERATOR_ID
    );
    $order->discard_changes;

    ok($order->is_on_credit_hold, 'Order is on credit hold');

    my $shipments = $order->shipments;
    while (my $shipment = $shipments->next){
        ok($shipment->is_on_finance_hold, 'Shipment is on finance hold');
    }

    # Mock has_validated_address so we don't go back on hold due to some logic
    # that is unrelated to this test
    {
    my $mocked = Test::MockModule->new('XTracker::Schema::Result::Public::Shipment');
    $mocked->mock(has_validated_address => 1);
    $self->{rdc}->release_order_from_credit_hold(
        'CustomerHasGenuineOrderHistory?', $order->id
    );
    }

    ok($order->discard_changes->is_accepted, 'Order is accepted');

    $shipments->reset;
    while (my $shipment = $shipments->next){
        ok($shipment->is_processing, 'Shipment is processing')
            or diag '... actually, shipment is ' . $shipment->shipment_status->status;
    }

    my $rdc_flag
      = $order->order_flags->find({flag_id => $FLAG__RELEASED_VIA_REMOTE_DC_QUERY});

    ok($rdc_flag, 'Remote DC flag is present');
}

sub place_order_on_credit_hold : Tests {
    my $self = shift;

    my $shipments_ref
      = get_order_shipment_info( $self->dbh, $self->{order}->id);

    ok($self->{order}->is_accepted, 'Order is accepted');

    my $shipments = $self->{order}->shipments;
    while (my $shipment = $shipments->next){
        ok($shipment->is_processing, 'Shipment is on finance hold');
    }

    $self->{rdc}->place_order_on_credit_hold('CustomerHasGenuineOrderHistory?',
                                             $self->{order}->id);
    $self->{order}->discard_changes;

    ok($self->{order}->is_on_credit_hold, 'Order is on credit hold');

    $shipments->reset;
    while (my $shipment = $shipments->next){
        ok($shipment->is_on_finance_hold, 'Shipment is on finance hold');
    }

    my $rdc_flag
      = $self->{order}->order_flags->find({flag_id => $FLAG__REMOTE_DC_QUERY_POTENTIAL_FRAUD});

    ok(defined $rdc_flag, 'Remote DC flag is present');
}

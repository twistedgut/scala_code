#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XT::Data;
use XTracker::Constants::FromDB     qw/:shipment_status /;
use XTracker::Order::Actions::ChangeOrderStatus;
use XTracker::Order::Utils::StatusChange;
use XTracker::Config::Local qw( config_var );

=head2  XTracker::Order::Actions::ChangeOrderStatus

    This test tests following methods of above package:

=over

=item _check_incorrect_website()

    Test when shipment country is of other DC then email is sent to customer care.

=back

=cut

sub setup :Tests(setup) {
    my $self = shift;

    $self->SUPER::setup();

    $self->{schema}      = Test::XTracker::Data->get_schema();
    $self->{status_utils}
      = XTracker::Order::Utils::StatusChange->new({schema => $self->{schema}});
}

sub test_check_incorrect_website_method : Tests() {
    my $self = shift;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
    my $customer            = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

    # Create a shipment with shipment country as same as currenct DC
    my $shipment = $self->_create_order( $pids, {
        customer_id => $customer->id,
        channel_id => $channel->id,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
    });

    # dummy data to supress warning  whhen running test
    my $order_info = {
        shipments => { $shipment->id => $shipment, },
        order_nr => '123',
        sales_channel => $channel->name,
    };

    # Check email does not gets sent
    my $result = $self->{status_utils}->check_incorrect_website($order_info);
    cmp_ok($result, '==', 0, "Email is NOT sent since shipment country is not on wrong DC");

    my $alternative_countries= config_var('IncorrectWebsiteCountry', 'country');
    my ($alt_country) = grep { not / $shipment->shipment_address->country/ } @{ $alternative_countries };

    # Update shipment country to country of other DC
    $shipment->update_or_create_related('shipment_address',{
        country => $alt_country,
    });

    no warnings "redefine";
    local *XTracker::Order::Actions::ChangeOrderStatus::send_email =  sub {
        note "***************** IN REDEFINED 'send_email' ***********";
        return 1;
    };
    use warnings "redefine";

    # Test that email gets sent as shipment_country is of other DC.
    $result = $self->{status_utils}->check_incorrect_website($order_info);
    cmp_ok($result, '==', 1, "Email is SENT sent since shipment country is On wrong DC");
}

sub _create_order {
    my $self    = shift;
    my $pids    = shift;
    my $args    = shift;

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Order',
    ]);

    $data = $data->new_order;
    my ( $channel, $customer, $order, $shipment ) = map { $data->{ $_ } }
        qw( channel_object customer_object order_object shipment_object );

    $shipment->update({shipment_status_id => $SHIPMENT_STATUS__PROCESSING});

    return $shipment;
}

Test::Class->runtests;

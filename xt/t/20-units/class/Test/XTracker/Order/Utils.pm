package Test::XTracker::Order::Utils;

use NAP::policy     qw( test class );

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};

use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;
use XTracker::Database::OrderPayment qw(process_payment);
use XTracker::Constants::FromDB qw( :department );
use XTracker::Constants::Payment qw( :psp_return_codes );
use XTracker::Order::Utils;
use XTracker::Config::Local qw/config_var/;

sub utils : Test(startup) {
    my $self = shift;

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state

    $self->{utils} = XTracker::Order::Utils->new( {
        schema => $self->schema,
    } );
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;

    Test::XTracker::Mock::PSP->use_all_original_methods();
}

sub create_order : Test(setup => no_plan) {
    my $self = shift;

    # start a transaction to be rolled back in 'teardown'
    $self->schema->txn_begin();

    my $channel_id = Test::XTracker::Data->channel_for_nap->id;
    my $customer
      = Test::XTracker::Data->find_customer({channel_id => $channel_id});

    my $shipping_account
      = Test::XTracker::Data->find_shipping_account(
            { channel_id  => $channel_id,
              acc_name    => 'Domestic',
              carrier     => config_var('DistributionCentre','default_carrier') });

    my $address
      = Test::XTracker::Data->create_order_address_in("current_dc_premier");

    my ($channel, $pids)
      = Test::XTracker::Data->grab_products({how_many => 1});

    # for each pid make sure there's stock
    foreach my $item (@{$pids}) {
        Test::XTracker::Data->ensure_variants_stock($item->{pid});
    }


    my $order = Test::XTracker::Data->create_domestic_order(
        channel => Test::XTracker::Data->channel_for_nap,
        pids => $pids );

    $self->{order} = $order;
    $self->{shipment} = $order->shipments->first;

    # make sure there is a Payment for the Order
    $order->discard_changes->payments->delete;
    # get Payment Refs. and remove 'settle_ref' as that will be done later
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    Test::XTracker::Data->create_payment_for_order( $order, $payment_args );
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;

    # rollback changes
    $self->schema->txn_rollback();
}


# Check whether billing address change is allowed/disallowed from various
# order states
sub can_change_billing_address : Tests {
    my $self = shift;

    # get the Payment Record
    my $payment = $self->{order}->payments->first;

    Test::XTracker::Data->prevent_editing_of_billing_address_for_payment( $payment );
    is($self->utils->billing_address_change_allowed($self->{order}->id),
       0,
       "Billing address edit NOT allowed when payment method doesn't allow it" );

    Test::XTracker::Data->allow_editing_of_billing_address_for_payment( $payment );
    # Order payment not yet settled - edit should be allowed
    is($self->utils->billing_address_change_allowed($self->{order}->id),
       1,
       "Billing address edit allowed when payment not yet settled & payment method allows it" );

    # Settle payment
    $self->settle_payment();

    # Payment settled - edit shouldn't be allowed
    is($self->utils->billing_address_change_allowed($self->{order}->id),
       0,
       "Billing address edit not allowed when payment is settled" );

}

# Check whether shipping address change is allowed/disallowed from various
# order states
sub can_change_shipping_address : Tests {
    my $self = shift;

    my $payment = $self->{order}->payments->first;

    Test::XTracker::Data->change_payment_to_allow_change_of_shipping_address_post_settlement($payment );
    # Allow shipping address update if shipment has no outward airway bill
    is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__IT),
       1,
       'Shipping address edit allowed when no airwaybill is set' );

    # Settle payment
    $self->settle_payment();

    # Disallow shipping address update if payment settled
    is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__IT),
       0,
       'Shipping address edit disallowed when payment taken for normal operator' );

    # Allow shipping address update if payment settled and I am special
    is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__SHIPPING),
       1,
       'Shipping address edit allowed when payment taken for DEPARTMENT__SHIPPING' );

    # Allow shipping address update if payment settled and I am special
    is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__SHIPPING_MANAGER),
       1,
       'Shipping address edit allowed when payment taken for DEPARTMENT__SHIPPING_MANAGER' );

    # Allow shipping address update if payment settled and I am special
    is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__DISTRIBUTION_MANAGEMENT),
       1,
       'Shipping address edit allowed when payment taken for DEPARTMENT__DISTRIBUTION_MANAGEMENT' );

    #Set 'allow_editing_of_shipping_address_after_settlement' to FALSE.
    Test::XTracker::Data->change_payment_to_not_allow_change_of_shipping_address_post_settlement($payment );

    # Disallow shipping address update if payment settled
    is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__DISTRIBUTION_MANAGEMENT),
       0,
       'Shipping address edit disallowed when payment taken for DEPARTMENT__DISTRIBUTION_MANAGEMENT
        and edit shipping address change is not allowed');

     is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__IT),
       0,
       'Shipping address edit disallowed when payment taken for DEPARTMENT__IT
        and edit shipping address change is not allowed');

    #Set 'allow_editing_of_shipping_address_after_settlement' to TRUE
    Test::XTracker::Data->change_payment_to_allow_change_of_shipping_address_post_settlement($payment );

    # Grab some airway bills
    my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;

    # Update the shipment airway bills
    $self->{shipment}->update_airwaybills( $out_awb, $ret_awb );

    is($self->utils->shipping_address_change_allowed($self->{order}->id,
                                                     $self->{shipment}->id,
                                                     $DEPARTMENT__IT),
       0,
      'Shipping address edit disallowed when outward airwaybill is set' );
}

sub settle_payment {
    my $self = shift;

    Test::XTracker::Mock::PSP->set_settle_payment_return_code(
        $PSP_RETURN_CODE__SUCCESS
    );

    my ( $order_nr, $web_conf_section )
      = process_payment( $self->schema, $self->{shipment}->id );

    return;
}


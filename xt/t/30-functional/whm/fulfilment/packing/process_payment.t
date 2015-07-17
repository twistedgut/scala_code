#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

process_payment.t - checks the Invoice created is as expected

=head1 DESCRIPTION

checks the Invoice created is as expected.

#TAGS fulfilment packing invoice sql http whm

=cut

use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::Mock::PSP;

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :currency
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :renumeration_status
                                        :renumeration_class
                                        :renumeration_type
                                    );

use XTracker::Config::Local             qw( config_var dc_address );
use Test::XT::Flow;


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

my $order       = _create_an_order();
my $shipment    = $order->shipments->first;
my $tenders     = $order->tenders;
my $renums      = $shipment->renumerations;
my $trans_code;
my $invoice;

$tenders->delete;
$renums->delete;

note "Order Nr/Id: ".$order->order_nr."/".$order->id;
note "Shipment Id: ".$shipment->id;
    my $framework = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
        ],
    );
    $framework->mech->force_datalite(1);

Test::XTracker::Data->set_department('it.god', 'Shipping');
__PACKAGE__->setup_user_perms;

    $framework->mech->do_login;

#
# NON Card Payment
# Can only check NON Card Payments (Store Credit etc.) as the PSP can't be mocked through the App.
#
note "Check NON Card Payment";

my $qc_field    = "";
my @items= $shipment->shipment_items->all;
foreach my $item ( @items ) {
    $qc_field   .= "&shipment_item_qc_".$item->id."=1";
}
$shipment->update( { store_credit => 120, shipping_charge => 20 } );

# Create a container in a packlane and associate it with a shipment item in this order.
# (Only if any pack lanes are set up.)
my $container;
my $packlane = $schema->resultset('Public::PackLane')->first;
if ($packlane) {
    my ($container_id) = Test::XT::Data::Container->create_new_containers({ how_many => 1, });
    $container = $schema->resultset('Public::Container')->find($container_id);
    $container->update( { pack_lane_id => $packlane->id, has_arrived => 1, arrived_at => 'now()' });
    $items[0]->update( { container_id => $container_id } );
}

# select packing station if we don't have one
$framework->mech__fulfilment__set_packing_station( $order->channel_id );


# PREVENT:
#  Use of uninitialized value $trans_code in concatenation (.) or string at process_payment.t line 63
$framework->mech->get_ok(
    '/Fulfilment/Packing/ProcessPayment?shipment_id='.$shipment->id.'&transaction_code='.($trans_code||'undefined-oops').$qc_field );
like( $framework->mech->uri, qr{Fulfilment/Packing/PackShipment}, "After 'ProcessPayment' went to 'PackShipment'" );

$order->discard_changes;
$shipment->discard_changes;
$invoice    = _check_invoice( $shipment );

# Ensure pack lane was removed and has_arrived reset for container associated with shipment item.
if ($packlane) {
    $container->discard_changes;
    is( $container->pack_lane_id, undef, 'pack lane ID has been removed from container' );
    ok( !($container->has_arrived), 'has_arrived flag was cleared' );
    ok( !defined($container->arrived_at), 'arrived_at was cleared' );
}

# Test Card Payment
TODO: {
    local $TODO = "Can't test Card Payments as can't Mock PSP through the App.";
    ok( 1 != 1 );
    last TODO;
}

done_testing();


#------------------------------------------------------------------------------------------------

# checks the Invoice created is as expected
sub _check_invoice {
    my $shipment    = shift;

    note "Checking Invoice";

    my $renum   = $shipment->renumerations->search( {}, { order_by => 'me.id DESC' } )->first;

    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'me.id ASC' } )->all;
    my @renum_items = $renum->renumeration_items->search( {}, { order_by => 'me.shipment_item_id ASC' } )->all;

    isa_ok( $renum, 'XTracker::Schema::Result::Public::Renumeration', "An Invoice was created" );
    cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Invoice: Type is 'Card Debit'" );
    cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__ORDER, "Invoice: Class is 'Order'" );
    cmp_ok( $renum->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, "Invoice: Status is 'Completed'" );
    cmp_ok( $renum->shipping, '==', $shipment->shipping_charge, "Invoice: 'Shipping' is ".$shipment->shipping_charge );
    cmp_ok( $renum->store_credit, '==', $shipment->store_credit, "Invoice: 'Store Credit' is ".$shipment->store_credit );

    cmp_ok( scalar( @renum_items ), '==', scalar( @ship_items ), "Invoice: Number of Items matches Shipment Items (".scalar( @ship_items ).")" );
    foreach my $idx ( 0..$#renum_items ) {
        cmp_ok( $renum_items[$idx]->unit_price, '==', $ship_items[$idx]->unit_price, "Invoice Item: 'unit_price' same as for Shipment Item (".$ship_items[$idx]->unit_price.")" );
    }

    return $renum;
}

# create an order
sub _create_an_order {

    my $args    = shift;

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
    });

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => config_var('DistributionCentre','default_carrier'), channel_id => $channel->id } );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                            ( $channel->is_on_dc( 'DC2' ) ? '11371' : 'NW10 4GR' ) );
    my $dc_address = dc_address($channel);
    my $address         = Test::XTracker::Data->order_address( {
                                                address         => 'create',
                                                address_line_1  => $dc_address->{addr1},
                                                address_line_2  => $dc_address->{addr2},
                                                address_line_3  => $dc_address->{addr3},
                                                towncity        => $dc_address->{city},
                                                county          => '',
                                                country         => $args->{country} || $dc_address->{country},
                                                postcode        => $postcode,
                                            } );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__PICKED,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
    };


    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
        attrs => [
            { price => 100.00 },
        ],
    });

    return $order;
}

sub setup_user_perms {
  Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
  # Perms needed for the order process
  for (qw/Packing/ ) {
    Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2);
  }
}

#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-141: Allow Customer to Accept Tax & Duty charges for Exchanges

This will test that when you use 'XT::Returns::Domain' passing in a flag indicating that the request came from 'ARMA' any renumeration DEBITs that are created because of charges for an Exchange will set the 'renumeration_status_id' to 'PENDING' and that when called without the 'request from ARMA' flag will set the status to 'AWAITING_AUTHORISATION' - which is currently how it works for all requests.

=cut



use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use Data::Dump      qw( pp );

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :return_status
                                        :renumeration_class
                                        :renumeration_status
                                        :renumeration_type
                                        :shipment_type
                                    );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

my $config  = \%XTracker::Config::Local::config;

$schema->txn_do( sub {
    my ( $order, $shipment, $ship_items )   = _create_an_order();

    # create the Returns Domain with the 'requested_from_arma' flag set
    my $domain = Test::XTracker::Data->returns_domain_using_dump_dir();
    $domain->requested_from_arma(1);

    cmp_ok( $domain->requested_from_arma, '==', 1, "'requested_from_arma' flag shown as TRUE" );

    # check '_can_set_debit_to_pending' is working
    $config->{DistributionCentre}{arma_accept_exchange_charges} = 'no';
    cmp_ok( $domain->_can_set_debit_to_pending, '==', 0, "'XT::Domain::Returns::Calc::_can_set_debit_to_pending' function returns FALSE" );
    $config->{DistributionCentre}{arma_accept_exchange_charges} = 'yes';
    cmp_ok( $domain->_can_set_debit_to_pending, '==', 1, "'XT::Domain::Returns::Calc::_can_set_debit_to_pending' function returns TRUE" );

    my %return_args = (
            operator_id => $APPLICATION_OPERATOR_ID,
            shipment_id => $shipment->id,
            pickup => 0,
            refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
            return_items => {
                    $ship_items->[0]->id    => {
                        type        => 'Exchange',
                        reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                        exchange_variant => $ship_items->[0]->variant_id,
                    },
                }
        );

    # create an Exchange, which should result in a Debit
    # payment for the tax and duties
    note "Create Exchange USING 'requested_from_arma' flag";
    my $return  = $domain->create( \%return_args );
    ok( $return, 'created return Id/RMA: '.$return->id.'/'.$return->rma_number );
    my $renum   = $return->renumerations->first;
    cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, "Return Renumeration is of Class 'Return'" );
    cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Return Renumeration Type is 'Card Debit'" );
    cmp_ok( $renum->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, "Return Renumeration Status is 'Pending'" );
    cmp_ok( $renum->total_value, '==', ( 5 + 15 ), "Return Renumeration Total is Tax + Duty" );

    # cancel the return
    my $stock_manager = $order->channel->stock_manager;
    $domain->cancel( {
            return_id   => $return->id,
            shipment_id => $shipment->id,
            operator_id => $APPLICATION_OPERATOR_ID,
            send_default_email => 0,
            stock_manager => $stock_manager,
        } );
    note "Cancelled Return";

    # create the Returns Domain without the 'requested_from_arma' flag set
    $domain->requested_from_arma(0);
    cmp_ok( $domain->requested_from_arma, '==', 0, "'requested_from_arma' flag shown as FALSE" );

    # check '_can_set_debit_to_pending' is working
    $config->{DistributionCentre}{arma_accept_exchange_charges} = 'no';
    cmp_ok( $domain->_can_set_debit_to_pending, '==', 0, "'XT::Domain::Returns::Calc::_can_set_debit_to_pending' function returns FALSE" );
    $config->{DistributionCentre}{arma_accept_exchange_charges} = 'yes';    # should still return false as 'requested_from_arma' flag is FALSE
    cmp_ok( $domain->_can_set_debit_to_pending, '==', 0, "'XT::Domain::Returns::Calc::_can_set_debit_to_pending' function returns FALSE" );

    note "Create Exchange NOT using 'requested_from_arma' flag";
    $return = $domain->create( \%return_args );
    ok( $return, 'created return Id/RMA: '.$return->id.'/'.$return->rma_number );
    $renum  = $return->renumerations->first;
    cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, "Return Renumeration is of Class 'Return'" );
    cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Return Renumeration Type is 'Card Debit'" );
    cmp_ok( $renum->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_AUTHORISATION, "Return Renumeration Status is 'Awaiting Authorisation'" );
    cmp_ok( $renum->total_value, '==', ( 5 + 15 ), "Return Renumeration Total is Tax + Duty" );

    # rollback changes
    $schema->txn_rollback();
} );


done_testing();

#-------------------------------------------------------------------------------------

# create an order
sub _create_an_order {

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
            # specifying NAP presumably because exchange refund rules are
            # different from other channels.
            channel     => Test::XTracker::Data->channel_for_nap,
    } );

    # use a Shipping Country that is not charge free
    my $country = Test::XTracker::Data->get_non_charge_free_state;

    my $base    = {
            shipping_charge => 17,
            create_renumerations => 1,
            shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
            tenders => [ { type => 'card_debit', value =>  ( ( 120 * 2 ) + 17 ) } ],
            invoice_address_id => Test::XTracker::Data->order_address( { address => 'create', country => $country->country } )->id,
        };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            attrs => [ map { price => 100, tax => 5, duty => 15 }, ( 1..2 ) ],
        } );
    ok($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr );

    my $shipment    = $order->get_standard_class_shipment;
    note "Shipment Id: ".$shipment->id;
    note "Shipping Country: ".$country->country;

    # create renumeration items
    my $renumeration= $shipment->renumerations->first;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'me.id' } )->all;
    foreach my $si ( @ship_items ) {
        $si->create_related( 'renumeration_items', {
                                        unit_price  => $si->unit_price,
                                        tax         => $si->tax,
                                        duty        => $si->duty,
                                        renumeration_id => $renumeration->id,
                                } );
    }

    return ( $order, $shipment, \@ship_items );
}


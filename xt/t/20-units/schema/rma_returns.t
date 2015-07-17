#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 RMA Returns - General testing of 'XT::Domain::Return*' functionality

This will test various small functionalities for the 'XT::Domain::Return*' modules, this will not deal with AMQ stuff this should be dealt with in '20-units/activemq' or for any large chunks of functionaliy, it should just act as a place to unit a few functions at a time.

Currently tests:
* Tests the Cloning of the original Shipment's 'signature_required' flag onto an Exhange Shipment that gets created (CANDO-216)
* Tests the '_localized_refund' & '_localized_exchange' methods to Refund/Charge Tax & Duty properly for the correct Countries
* Tests that Shipping Charge is not refunded more than once
* Tests methods associated with 'Public::ReturnEmailLog' class
* Tests 'XTracker::Database::Return::release_return_invoice' function

=cut

use Test::Exception;
use Test::MockObject;

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XT::Data;

use Data::Dump      qw( pp );
use DateTime;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :refund_charge_type
                                        :return_type
                                        :return_item_status
                                        :return_status
                                        :renumeration_status
                                        :renumeration_type
                                        :reservation_status
                                        :shipment_item_status
                                        :shipment_status
                                    );
use XTracker::Database::Return      qw( calculate_refund_charge_per_item release_return_invoice );

use_ok( 'XTracker::Order::Functions::Return::AddItem' ),
use_ok( 'XTracker::Order::Functions::Return::ConvertFromExchange' );
use_ok( 'XTracker::Order::Functions::Return::ConvertToExchange' );
can_ok( 'XTracker::Order::Functions::Return::AddItem', '_process_items' );
can_ok( 'XTracker::Order::Functions::Return::ConvertFromExchange', '_get_unit_tax_duty_refunds' );
can_ok( 'XTracker::Order::Functions::Return::ConvertToExchange', '_get_tax_duty_charges' );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

# get a new instance of 'XT::Domain::Return'
my $domain  = Test::XTracker::Data->returns_domain_using_dump_dir();
my $amq = $domain->msg_factory();

#----------------------------------------------------------
_test_exchange( $schema, $domain, $amq, 1 );
_test_refund_exchange_tax_duties( $schema, $domain, $amq, 1 );
_test_shipping_charge( $schema, $domain, $amq, 1 );
_test_return_email_log( $schema, $domain, $amq, 1 );
_test_release_return_invoice( $schema, $domain, $amq, 1 );
#----------------------------------------------------------

done_testing();

# various exchange tests
sub _test_exchange {
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    SKIP: {
        skip "_test_exchange", 1        if ( !$oktodo );

        note "in '_test_exchange'";

        $schema->txn_do( sub {

            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order();

            # get the Variants and an Alternative Size for each
            my $variant1        = $pids->[0]{variant};
            my $variant2        = $pids->[1]{variant};
            my %alt_variants    = map { $_->sku => $_ } grep { $_->size_id != $variant1->size_id } $pids->[0]{product}->variants->all;
            my ( $alt_variant1 )= values %alt_variants;
            %alt_variants       = map { $_->sku => $_ } grep { $_->size_id != $variant2->size_id } $pids->[1]{product}->variants->all;
            my ( $alt_variant2 )= values %alt_variants;

            # clear all reservations for the Variants
            $variant1->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );
            $alt_variant1->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );
            $variant2->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );
            $alt_variant2->reservations->update( { status_id => $RESERVATION_STATUS__CANCELLED, ordering_id => 0 } );

            note "test Cloning the Original Shipments 'signature_required' flag for the Exchange Shipment";

            # set-up the Args for creating an Exchange
            my %return_args = (
                    operator_id => $APPLICATION_OPERATOR_ID,
                    shipment_id => $shipment->id,
                    pickup => 0,
                    refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                    return_items => {
                            $items->[0]->id => {
                                type        => 'Exchange',
                                reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                exchange_variant => $alt_variant1->id,
                            },
                        }
                );
            # set-up Args used to cancel an Exchange
            my %cancel_args = (
                    shipment_id => $shipment->id,
                    operator_id => $APPLICATION_OPERATOR_ID,
                    send_default_email => 0,
                );

            note "test with a NULL value";
            $shipment->update( { signature_required => undef } );
            my $return  = $domain->create( \%return_args );
            ok( !defined $return->exchange_shipment->signature_required, "Exchange Shipment has a NULL 'signature_required' field" );
            cmp_ok( $return->shipment->is_signature_required, '==', 1, "Exchange Shipment 'is_signature_required' returns TRUE" );
            my $stock_manager = $order->channel->stock_manager;
            $domain->cancel( { %cancel_args, return_id => $return->id, stock_manager => $stock_manager } );

            note "test with a TRUE value";
            $shipment->update( { signature_required => 1 } );
            $return = $domain->create( \%return_args );
            cmp_ok( $return->exchange_shipment->signature_required, '==', 1, "Exchange Shipment has a TRUE 'signature_required' field" );
            $domain->cancel( { %cancel_args, return_id => $return->id, stock_manager => $stock_manager } );

            note "test with a FALSE value";
            $shipment->update( { signature_required => 0 } );
            $return = $domain->create( \%return_args );
            cmp_ok( $return->exchange_shipment->signature_required, '==', 0, "Exchange Shipment has a FALSE 'signature_required' field" );

            note "test creating an Exchange of the Exchange still uses the Original flag and not the first Exchange's flag";
            note "original Shipment will have a FALSE value where as the recent Exchange Shipment will have a TRUE value";
            $shipment->update( { signature_required => 0 } );
            $return->exchange_shipment->update( { signature_required => 1 } );
            # dispatch the Exchange Shipment & Complete the Return
            $return->exchange_shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
            $return->exchange_shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
            $return->update( { return_status_id => $RETURN_STATUS__COMPLETE } );
            $return->return_items->update( { return_item_status_id => $RETURN_ITEM_STATUS__PUT_AWAY } );
            # now use the Exchange Shipment Item in the Return
            $return_args{shipment_id}   = $return->exchange_shipment_id;
            $return_args{return_items}  = {
                                $return->exchange_shipment->shipment_items->first->id   => {
                                    type        => 'Exchange',
                                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    exchange_variant => $items->[0]->variant_id,
                                },
                            };
            $return = $domain->create( \%return_args );
            cmp_ok( $return->exchange_shipment->signature_required, '==', 0, "Exchange of an Exchange Shipment has a FALSE 'signature_required' field" );


            note "Now Create an Exchange for a Variant which has Reservations against it";

            # create reservations, one for the Same Customer as the Order and one for a different Customer
            my ( $order_res )   = _create_reservations( 1, $channel, $alt_variant2, $order->customer );
            my ( $other_res )   = _create_reservations( 1, $channel, $alt_variant2 );
            $order_res->update( { status_id => $RESERVATION_STATUS__UPLOADED } );

            %return_args = (
                    operator_id => $APPLICATION_OPERATOR_ID,
                    shipment_id => $shipment->id,
                    pickup => 0,
                    refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                    return_items => {
                            $items->[1]->id => {
                                type        => 'Exchange',
                                reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                exchange_variant => $alt_variant2->id,
                            },
                        }
                );
            $return = $domain->create( \%return_args );

            # check that the Order Customer's Reservation has been Cancelled
            # but the other Pending Reservation has not been Uploaded
            cmp_ok( $order_res->discard_changes->status_id, '==', $RESERVATION_STATUS__CANCELLED, "Order Customer's Reservation has been 'Cancelled'" );
            cmp_ok( $other_res->discard_changes->status_id, '==', $RESERVATION_STATUS__PENDING, "The Other Customer's Reservation is still 'Pending'" );


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# tests the '_localized_refund' & '_localized_exchange' methods
# refund or charge Tax &/or Duties appropriately based on
# the shipping country and certain exceptions, Also tests the
# old style 'XTracker::Database::Return::calculate_refund_charge_per_item()'
# function for the same stuff as this is still used to render the RMA Emails
sub _test_refund_exchange_tax_duties {
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    SKIP: {
        skip "_test_refund_exchange_tax_duties", 1      if ( !$oktodo );

        note "in '_test_refund_exchange_tax_duties'";

        $schema->txn_do( sub {
            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order();

            # get the countries used in the Order
            my $inv_country = $order->invoice_address->country_table;
            my $ship_country= $shipment->shipment_address->country_table;

            # delete any Return Refund Charge records
            # for the countries or their Sub-Regions
            # so that we can set our own for the test
            $inv_country->return_country_refund_charges->delete;
            $inv_country->sub_region->return_sub_region_refund_charges->delete;
            $ship_country->return_country_refund_charges->delete;
            $ship_country->sub_region->return_sub_region_refund_charges->delete;

            # Add Return Refund Charge records to the
            # Invoice country which should have no bearing
            # on the Tax & Duties refunded/charged for the
            # return as only the Shipping Address should be used
            _create_country_refund_charges( $inv_country, 1, $REFUND_CHARGE_TYPE__TAX, $REFUND_CHARGE_TYPE__DUTY );

            # mock-up the requirements that the methods
            # '_localized_refund' & '_localized_exchange' use

            my $ship_item       = $items->[0];
            $ship_item->update( { unit_price => 150, tax => 10, duty => 30 } );
            my %ret_item    = (
                    shipment_item_id=> $ship_item->id,
                    _reason_id      => $CUSTOMER_ISSUE_TYPE__7__FABRIC,
                    _tax            => $ship_item->tax,
                    _duty           => $ship_item->duty,
                    unit_price      => $ship_item->unit_price,
                    tax             => 0,
                    duty            => 0,
                    type            => 'Return',
                );
            my %exch_item   = (
                    %ret_item,
                    type        => 'Exchange',
                    exchange    => $ship_item->get_true_variant->sku,
                );
            my $full_refund_amnt    = $ret_item{unit_price} + $ret_item{_tax} + $ret_item{_duty};

            note "check 'calculate_refund_charge_per_item' function dies when not passed a Schema";
            dies_ok( sub {
                    calculate_refund_charge_per_item( $schema->storage->dbh, { %ret_item }, $ship_item, { country => $ship_country->country } );
                }, "'calculate_refund_charge_per_item' dies when not passed a Schema object" );

            note "run through Execptions that always refund or never charge Tax & Duties";

            # with no Return Refund Charge records for the
            # Shipping Country go through the Exceptions which
            # mean Tax & Duties are always refunded or never charged
            my %exceptions  = (
                    'Customer Reason: Incorrect Item'   => {
                            item    => { _reason_id  => $CUSTOMER_ISSUE_TYPE__7__INCORRECT_ITEM },
                        },
                    'Customer Reason: Defective/Faulty' => {
                            item    => { _reason_id  => $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY },
                        },
                    'A Full Refund Requested'   => {
                            item    => { full_refund => 1 },
                            for_refund_only => 1,
                        },
                );

            foreach my $label ( sort keys %exceptions ) {
                my $test    = $exceptions{ $label };
                note "exception: $label";

                # clone the above item hash so it isn't overwritten everytime
                # and then blend in the exceptions to it
                my %item_clone  = ( %ret_item, %{ $test->{item} } );
                _check_refunded_ok( $domain, \%item_clone, $full_refund_amnt, $ret_item{_tax}, $ret_item{_duty} );
                next    if ( exists( $test->{for_refund_only} ) );

                %item_clone = ( %exch_item, %{ $test->{item} } );
                _check_charged_ok( $domain, \%item_clone, 0, 0, 0 );    # should be charged nothing
            }

            note "test 'Lost Shipments' are refunded Tax & Duties as well";
            $domain->{is_lost_shipment} = 1;
            # pass in a cloned version of %ret_item so it doesn't get overridden and affect subsequent tests
            _check_refunded_ok( $domain, { %ret_item }, $full_refund_amnt, $ret_item{_tax}, $ret_item{_duty} );
            delete $domain->{is_lost_shipment};

            note "test 'Dispatch/Return' is refunded Tax & Duties as well";
            $domain->{dispatch_return}  = 1;
            _check_refunded_ok( $domain, { %ret_item }, $full_refund_amnt, $ret_item{_tax}, $ret_item{_duty} );
            delete $domain->{dispatch_return};

            note "test a Country with no Return Refund Charge records for Tax & Duty doesn't Refund either, but charges for both on an Exchange";
            _check_refunded_ok( $domain, { %ret_item }, $ret_item{unit_price}, 0, 0 );
            # expected values should all be negative
            _check_charged_ok( $domain, { %exch_item }, -( $exch_item{_tax} + $exch_item{_duty} ), -$exch_item{_tax}, -$exch_item{_duty} );


            note "test that when a Country has 'can_refund_for_return' set for either Tax or Duty it Refunds each appropriately";

            note "when a Country should only refund Tax";
            _create_country_refund_charges( $ship_country, 1, $REFUND_CHARGE_TYPE__TAX );
            _check_refunded_ok( $domain, { %ret_item }, $ret_item{unit_price} + $ret_item{_tax}, $ret_item{_tax}, 0 );

            note "when a Country should only refund Duty";
            _update_country_refund_charges( $ship_country, 'can_refund_for_return', 0, $REFUND_CHARGE_TYPE__TAX );  # turn off refunding Tax
            _create_country_refund_charges( $ship_country, 1, $REFUND_CHARGE_TYPE__DUTY );
            _check_refunded_ok( $domain, { %ret_item }, $ret_item{unit_price} + $ret_item{_duty}, 0, $ret_item{_duty} );

            note "when a Country should refund Tax & Duty";
            _update_country_refund_charges( $ship_country, 'can_refund_for_return', 1, $REFUND_CHARGE_TYPE__TAX );  # turn on refunding Tax
            _check_refunded_ok( $domain, { %ret_item }, $full_refund_amnt, $ret_item{_tax}, $ret_item{_duty} );

            # get rid of all refund charge records for next set of tests
            $ship_country->return_country_refund_charges->delete;


            note "test that when a Country has 'no_charge_for_exchange' set for either Tax or Duty it doesn't Charge each appropriately";

            note "when a Country shouldn't charge Tax but should charge Duty";
            _create_country_refund_charges( $ship_country, 1, $REFUND_CHARGE_TYPE__TAX );
            _check_charged_ok( $domain, { %exch_item }, -$exch_item{_duty}, 0, -$exch_item{_duty} );

            note "when a Country shouldn't charge Duty but should charge Tax";
            _update_country_refund_charges( $ship_country, 'no_charge_for_exchange', 0, $REFUND_CHARGE_TYPE__TAX );  # turn off not charging Tax
            _create_country_refund_charges( $ship_country, 1, $REFUND_CHARGE_TYPE__DUTY );
            _check_charged_ok( $domain, { %exch_item }, -$exch_item{_tax}, -$exch_item{_tax}, 0 );

            note "when a Country should not charge either Tax or Duty";
            _update_country_refund_charges( $ship_country, 'no_charge_for_exchange', 1, $REFUND_CHARGE_TYPE__TAX );  # turn on not charging Tax
            _check_charged_ok( $domain, { %exch_item }, 0, 0, 0 );      # shouldn't get charged anything


            # rollback changes
            $schema->txn_rollback();
        } );
    };
}

# tests that the Shipping Charge is not refunded
# more than once when a 'full_refund' is asked for
sub _test_shipping_charge {
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    SKIP: {
        skip "_test_shipping_charge", 1     if ( !$oktodo );

        note "in '_test_shipping_charge'";

        $schema->txn_do( sub {
            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order( 3 );
            cmp_ok( $shipment->shipping_charge, '==', 10, "sanity check Shipment has a Shipping Charge" );

            # set 'orders.tender' value to something high so
            # not enough tenders remaining error doesn't occur
            $order->tenders->update( { value => 10000 } );

            note "TEST first Return Refunds Shipping Charge";
            # set-up the Args for creating an Exchange
            my %return_args = (
                    operator_id => $APPLICATION_OPERATOR_ID,
                    shipment_id => $shipment->id,
                    pickup => 0,
                    refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                    return_items => {
                            $items->[0]->id => {
                                type        => 'Return',
                                reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                full_refund => 1,
                            },
                        },
                );
            my $return  = $domain->create( \%return_args );
            my $renum   = $return->renumerations->first;
            cmp_ok( $renum->shipping, '==', $shipment->shipping_charge, "Refund includes Shipping Charge" );

            note "TEST second Return DOES NOT Refund Shipping Charge";
            $return_args{return_items}  = {
                                $items->[1]->id => {
                                    type        => 'Return',
                                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    full_refund => 1,
                                },
                            };
            $return = $domain->create( \%return_args );
            $renum  = $return->renumerations->first;
            cmp_ok( $renum->shipping, '==', 0, "Refund DOES NOT include Shipping Charge" );

            note "TEST third Return DOES NOT Refund Shipping Charge to make sure multiple previous Refunds don't cause a problem";
            $return_args{return_items}  = {
                                $items->[2]->id => {
                                    type        => 'Return',
                                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    full_refund => 1,
                                },
                            };
            $return = $domain->create( \%return_args );
            $renum  = $return->renumerations->first;
            cmp_ok( $renum->shipping, '==', 0, "Refund Still DOES NOT include Shipping Charge" );

            # rollback any changes
            $schema->txn_rollback();
        } );
    };
}

# tests getting the Return Email Log used for the
# Order View and Return Details pages
sub _test_return_email_log {
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    SKIP: {
        skip "_test_return_email_log", 1        if ( !$oktodo );

        note "in '_test_return_email_log'";

        $schema->txn_do( sub {

            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order();

            # set-up the Args for creating a Return
            my %return_args = (
                    operator_id => $APPLICATION_OPERATOR_ID,
                    shipment_id => $shipment->id,
                    pickup => 0,
                    refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                    return_items => {
                            $items->[0]->id => {
                                type        => 'Return',
                                reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                            },
                        }
                );
            # create a Return
            my $return1 = $domain->create( \%return_args );
            # create another Return
            $return_args{return_items}  = {
                                $items->[1]->id => {
                                    type        => 'Return',
                                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                },
                            };
            my $return2 = $domain->create( \%return_args );

            note "Return1 RMA/Id: " . $return1->rma_number."/".$return1->id;
            note "Return2 RMA/Id: " . $return2->rma_number."/".$return2->id;

            # test '*_correspondence_logs' methods return a 'ResulSet'
            isa_ok( $shipment->get_return_correspondence_logs, 'XTracker::Schema::ResultSet::Public::ReturnEmailLog',
                                        "'\$shipment->get_return_correspondence_logs' returns correct type" );
            isa_ok( $return1->get_correspondence_logs, 'XTracker::Schema::ResultSet::Public::ReturnEmailLog',
                                        "'\$return->get_correspondence_logs' returns correct type" );

            # test when no log records exist
            ok( !defined $shipment->get_return_correspondence_logs->formatted_for_page,
                                "Called from Shipment: 'formatted_for_page' called with no logs returns 'undef'" );
            ok( !defined $return1->get_correspondence_logs->formatted_for_page,
                                "Called from Return: 'formatted_for_page' called with no logs returns 'undef'" );

            # get some dates for the logs to test 'in_created_order' method
            my $today       = DateTime->now( time_zone => 'local' );
            my $tomorrow    = $today->clone->add( days => 1, hours => 3, minutes => 2 );
            my $yesterday   = $today->clone->subtract( days => 1, hours => 2, minutes => 5 );

            # create correspondence for the Returns
            my @templates   = $schema->resultset('Public::CorrespondenceTemplate')->search( {}, { rows => 3, order_by => 'id' } )->all;
            $return2->create_related( 'return_email_logs', {
                                                        correspondence_templates_id => $templates[2]->id,
                                                        operator_id                 => $APPLICATION_OPERATOR_ID,
                                                        date                        => $tomorrow,
                                                    } );
            $return1->create_related( 'return_email_logs', {
                                                        correspondence_templates_id => $templates[1]->id,
                                                        operator_id                 => $APPLICATION_OPERATOR_ID,
                                                        date                        => $yesterday,
                                                    } );
            $return2->create_related( 'return_email_logs', {
                                                        correspondence_templates_id => $templates[0]->id,
                                                        operator_id                 => $APPLICATION_OPERATOR_ID,
                                                        date                        => $today,
                                                    } );

            my @logs    = $shipment->get_return_correspondence_logs->in_created_order->all;
            cmp_ok( @logs, '==', 3, "'in_created_order' Found 3 Logs" );
            cmp_ok( $logs[0]->correspondence_templates_id, '==', $templates[1]->id, "'in_created_order' First Log Template is correct" );
            ok( !DateTime->compare( $logs[0]->date, $yesterday ), "'in_created_order' First Log Date is correct" );
            cmp_ok( $logs[1]->correspondence_templates_id, '==', $templates[0]->id, "'in_created_order' Second Log Template is correct" );
            ok( !DateTime->compare( $logs[1]->date, $today ), "'in_created_order' Second Log Date is correct" );
            cmp_ok( $logs[2]->correspondence_templates_id, '==', $templates[2]->id, "'in_created_order' Third Log Template is correct" );
            ok( !DateTime->compare( $logs[2]->date, $tomorrow ), "'in_created_order' Third Log Date is correct" );

            my @expected;
            my $date_format     = 'dd-MM-yyyy  HH:mm';
            foreach my $log ( @logs ) {
                    push @expected, {
                            id          => $log->id,
                            log_obj     => $log,
                            rma_number  => $log->return->rma_number,
                            operator    => $log->operator->name,
                            template    => $log->correspondence_template->name,
                            date        => $log->date->format_cldr( $date_format ),
                        },
            }
            # call from a 'Shipment' for all Returns
            my $got = $shipment->get_return_correspondence_logs->formatted_for_page;
            is_deeply( $got, \@expected, "Called from Shipment: 'formatted_for_page' returned as expected" );

            # call from a 'Return'
            @expected   = ( $expected[1], $expected[2] );       # only the last 2 are for $return2
            $got    = $return2->get_correspondence_logs->formatted_for_page;
            is_deeply( $got, \@expected, "Called from Return: 'formatted_for_page' returned as expected" );


            # rollback changes
            $schema->txn_rollback();
        } );
    };
}

# test the 'release_return_invoice' function to make sure
# it releases correctly and make sure that 'Cancelled'
# return items don't trigger the release
sub _test_release_return_invoice {
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    SKIP: {
        skip "_test_release_return_invoice", 1        if ( !$oktodo );

        note "in '_test_rrelease_return_invoice'";

        $schema->txn_do( sub {

            my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order();

            # set-up the Args for creating a Return
            my %return_args = (
                    operator_id => $APPLICATION_OPERATOR_ID,
                    shipment_id => $shipment->id,
                    pickup => 0,
                    refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                    return_items => {
                            $items->[0]->id => {
                                type        => 'Return',
                                reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                            },
                            $items->[1]->id => {
                                type        => 'Return',
                                reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                            },
                        }
                );
            # create a Return
            my $return  = $domain->create( \%return_args );
            my @ritems  = $return->return_items->search( {}, { order_by => 'id' } )->all;
            my $renum   = $return->renumerations->first;

            # get the Return Item Statuses that Should & Shouldn't allow a Release
            my %ritem_statuses  = map { $_->id => $_ }
                                        $schema->resultset('Public::ReturnItemStatus')->all;
            my @notallow_statuses  = map { delete $ritem_statuses{ $_ } }
                                        (
                                            $RETURN_ITEM_STATUS__AWAITING_RETURN,
                                            $RETURN_ITEM_STATUS__BOOKED_IN,
                                            $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
                                            $RETURN_ITEM_STATUS__CANCELLED,
                                        );
            my @allow_statuses      = values %ritem_statuses;

            note "check Return Item Statuses that Shouldn't Release an Invoice";
            foreach my $status ( @notallow_statuses ) {
                note "Status: " . $status->status;
                $return->return_items->update( { return_item_status_id => $status->id } );
                my @result  = release_return_invoice( $schema, $return->id );
                cmp_ok( @result, '==', 0, "'release_return_invoice' returned an Array of ZERO Items" );
            }

            note "check Return Item Statuses that Should Release an Invoice";
            foreach my $status ( @allow_statuses ) {
                note "Status: " . $status->status;
                $return->return_items->update( { return_item_status_id => $status->id } );
                my @result  = release_return_invoice( $schema, $return->id );
                cmp_ok( @result, '==', 1, "'release_return_invoice' returned an Array of 1 Items" );
                cmp_ok( $result[0], '==', $renum->id, "and first item is the Id of the Renumeration" );
            }

            # with one Item in a Releasable Status, Cancel the other the function
            # should NOT Release the Invoice as Cancelled Return Items should be ignored.
            # This is not a real-world scenario as when you cancel a Return Item it's
            # corresponding Invoice Item should be deleted, but this reliably shows if there is a
            # Bug where there are Cancelled Return Items with the same Shipment Item Id as
            # a Non-Cancelled Return Item, a more real-world scenario follows this test
            note "with 1 Return Item Releasable and the other Cancelled";
            $ritems[0]->discard_changes->update( { return_item_status_id => $RETURN_ITEM_STATUS__CANCELLED } );
            my @result  = release_return_invoice( $schema, $return->id );
            cmp_ok( @result, '==', 0, "'release_return_invoice' returned an Array with ZERO Items" );

            # A real-world scenario for the above
            # now simulate a Convert of an Exchange to a Return by
            # cancelling one Item and creating a new one with the
            # same Shipment Item Id, make sure the other item is Releaseable
            note "have one Return Item Cancelled and another with the same Shipment Item Id in an Un-Releasable Status";
            my %ret_item    = $ritems[0]->discard_changes->get_columns;
            delete $ret_item{id};
            delete $ret_item{return_id};
            $ritems[0]->update( { return_item_status_id => $notallow_statuses[0]->id } );
            my $new_item    = $return->create_related( 'return_items', { %ret_item, return_type_id => $RETURN_TYPE__EXCHANGE, return_item_status_id => $RETURN_ITEM_STATUS__CANCELLED } );
            @result = release_return_invoice( $schema, $return->id );
            cmp_ok( @result, '==', 0, "'release_return_invoice' returned an Array with ZERO Items" );


            # check Renumeration Statuses that Should & Shouldn't be Releasable

            # make sure the Return Items will be Releasable
            $new_item->delete;
            $ritems[0]->update( { return_item_status_id => $allow_statuses[0]->id } );

            # get the Renumeration Statuses that Should & Shouldn't allow a Release
            my %renum_statuses      = map { $_->id => $_ }
                                        $schema->resultset('Public::RenumerationStatus')->all;
            my @allow_renum_statuses= map { delete $renum_statuses{ $_ } }
                                        (
                                            $RENUMERATION_STATUS__PENDING,
                                        );

            note "check Renumeration Statuses that Shouldn't Release an Invoice";
            foreach my $status ( values %renum_statuses ) {
                note "Status: " . $status->status;
                $renum->update( { renumeration_status_id => $status->id } );
                my @result  = release_return_invoice( $schema, $return->id );
                cmp_ok( @result, '==', 0, "'release_return_invoice' returned an Array of ZERO Items" );
            }

            note "check Renumeration Statuses that Should Release an Invoice";
            foreach my $status ( @allow_renum_statuses ) {
                note "Status: " . $status->status;
                $renum->update( { renumeration_status_id => $status->id } );
                my @result  = release_return_invoice( $schema, $return->id );
                cmp_ok( @result, '==', 1, "'release_return_invoice' returned an Array of 1 Items" );
                cmp_ok( $result[0], '==', $renum->id, "and first item is the Id of the Renumeration" );
            }


            note "check with mutliple Renumerations for a Return";

            # create a new Renumeration and assign a Renumeration Item to it
            my %renum_rec   = $renum->get_columns;
            delete $renum_rec{id};
            my $new_renum   = $schema->resultset('Public::Renumeration')->create( \%renum_rec );
            $return->create_related( 'link_return_renumerations', { renumeration_id => $new_renum->id } );
            my $renum_item  = $renum->renumeration_items->search( { shipment_item_id => $ritems[0]->shipment_item_id } )->first;
            $renum_item->update( { renumeration_id => $new_renum->id } );
            $new_renum->discard_changes;
            $renum->discard_changes;
            $ritems[0]->discard_changes;
            $ritems[1]->discard_changes;

            note "with 2 Releasable Return Items both Invoices Should be Released";
            @result = release_return_invoice( $schema, $return->id );
            cmp_ok( @result, '==', 2, "'release_return_invoice' returned an Array of 2 Items" );
            is_deeply( { map { $_ => 1 } @result }, { $renum->id => 1, $new_renum->id => 1 }, "and both items are the Ids of the Renumerations" );

            note "make one Return Item Un-Releasable, only One Invoice should be Released";
            $ritems[1]->update( { return_item_status_id => $notallow_statuses[0]->id } );
            @result = release_return_invoice( $schema, $return->id );
            cmp_ok( @result, '==', 1, "'release_return_invoice' returned an Array of 1 Items" );
            cmp_ok( $result[0], '==', $new_renum->id, "and first item is the Id of the New Renumeration" );

            note "make the other Return Item Un-Releasable, only One Invoice should be Released";
            $ritems[0]->update( { return_item_status_id => $notallow_statuses[0]->id } );
            $ritems[1]->update( { return_item_status_id => $allow_statuses[0]->id } );
            @result = release_return_invoice( $schema, $return->id );
            cmp_ok( @result, '==', 1, "'release_return_invoice' returned an Array of 1 Items" );
            cmp_ok( $result[0], '==', $renum->id, "and first item is the Id of the Original Renumeration" );

            note "make both Return Items Un-Releasable, no Invoices should be Released";
            $ritems[0]->update( { return_item_status_id => $notallow_statuses[0]->id } );
            $ritems[1]->update( { return_item_status_id => $notallow_statuses[0]->id } );
            @result = release_return_invoice( $schema, $return->id );
            cmp_ok( @result, '==', 0, "'release_return_invoice' returned an Array of ZERO Items" );


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

#-------------------------------------------------------------------------------------

# call '_localized_refund' and 'calculate_refund_charge_per_item'
# to check that what gets Refunded is Correct
sub _check_refunded_ok {
    my ( $domain, $item, $exp_total, $exp_tax, $exp_duty )      = @_;

    # get the Shipment Item and the Shipment Address
    my $ship_item   = $domain->schema->resultset('Public::ShipmentItem')->find( $item->{shipment_item_id} );
    my $ship_addr   = { $ship_item->shipment->shipment_address->get_columns };

    my %item_clone  = %{ $item };       # clone the item for the function test after the method

    note "call the '_localized_refund' method and check the result";
    my $total   = $domain->_localized_refund( $item );
    cmp_ok( $total, '==', $exp_total, "Total Refund given as expected: $exp_total" );
    cmp_ok( $item->{tax}, '==', $exp_tax, "'tax' value in HASH same as expected: $exp_tax" );
    cmp_ok( $item->{duty}, '==', $exp_duty, "'duty' value in HASH same as expected: $exp_duty" );

    return  if ( $domain->{is_lost_shipment} || $domain->{dispatch_return} );   # don't check the function for Lost Shipments or Dispatch/Returns

    note "call the 'calculate_refund_charge_per_item' function and check the result";
    $item_clone{reason_id}  = delete $item_clone{_reason_id};
    my @values  = calculate_refund_charge_per_item( $domain->schema, \%item_clone, $ship_item, $ship_addr );
    cmp_ok( $values[0], '==', 1, "'got_refund' flag set to 1" );
    ok( !defined $values[1], "'charge_duty' is 'undef'" );
    ok( !defined $values[2], "'charge_tax' is 'undef'" );
    ok( !defined $values[3], "'num_exchange_items' is 'undef'" );
    cmp_ok( $item_clone{tax}, '==', $exp_tax, "'tax' value in HASH as expected: $exp_tax" );
    cmp_ok( $item_clone{duty}, '==', $exp_duty, "'duty' value in HASH as expected: $exp_duty" );

    # test the 'Order::Functions::Return::AddItem::_process_items'
    # function which is used when Manually Adding Return Items
    %item_clone = %{ $item };
    note "call the 'XTracker::Order::Functions::Return::AddItem::_process_items' function and check the result";
    my $item_args   = _mock_up_add_items_arguments( $domain, $ship_item, $ship_addr, \%item_clone, 'Add' );
    XTracker::Order::Functions::Return::AddItem::_process_items( $item_args );
    my $add_item    = $item_args->{data}{return_items}{ $ship_item->id };
    cmp_ok( $item_args->{data}{num_return_items}, '==', 1, "'num_return_items' value is 1" );
    cmp_ok( $add_item->{return}, '==', 1, "'return' flag in HASH is 1" );
    cmp_ok( $add_item->{unit_price}, '==', $item->{unit_price}, "'unit_price' value in HASH same as expected: ".$item->{unit_price} );
    cmp_ok( $add_item->{tax}, '==', $exp_tax, "'tax' value in HASH same as expected: $exp_tax" );
    cmp_ok( $add_item->{duty}, '==', $exp_duty, "'duty' value in HASH same as expected: $exp_duty" );

    return      if ( exists( $item->{full_refund} ) );      # don't test 'Full Refund' exception for Convert From Exchange

    # test the 'Order::Functions::Return::ConvertFromExchange::_get_unit_tax_duty_refunds'
    # function which is used when Manually Converting From an Exchange
    %item_clone = %{ $item };
    note "call the 'XTracker::Order::Functions::Return::ConvertFromExchange::_get_unit_tax_duty_refunds' function and check the result";
    $item_args  = _mock_up_add_items_arguments( $domain, $ship_item, $ship_addr, \%item_clone, 'ConvertFromExchange' );
    XTracker::Order::Functions::Return::ConvertFromExchange::_get_unit_tax_duty_refunds( $item_args );
    my $conv_item   = $item_args->{data}{return_items}{ $ship_item->id };
    cmp_ok( $conv_item->{refund_unit}, '==', $item->{unit_price}, "'refund_unit' value in HASH same as expected: ".$item->{unit_price} );
    cmp_ok( $conv_item->{refund_tax}, '==', $exp_tax, "'refund_tax' value in HASH same as expected: $exp_tax" );
    cmp_ok( $conv_item->{refund_duty}, '==', $exp_duty, "'refund_duty' value in HASH same as expected: $exp_duty" );

    return;
}

# call '_localized_exchange' and 'calculate_refund_charge_per_item'
# to check that what gets Refunded is Correct, expected values passed
# in should all be negative
sub _check_charged_ok {
    my ( $domain, $item, $exp_total, $exp_tax, $exp_duty )      = @_;

    # get the Shipment Item and the Shipment Address
    my $ship_item   = $domain->schema->resultset('Public::ShipmentItem')->find( $item->{shipment_item_id} );
    my $ship_addr   = { $ship_item->shipment->shipment_address->get_columns };

    my %item_clone  = %{ $item };       # clone the item for the function test after the method

    note "call the '_localized_exchange' method and check the result";
    my $total   = $domain->_localized_exchange( $item );
    cmp_ok( $total, '==', $exp_total, "Total Charge as expected: $exp_total" );
    cmp_ok( $item->{tax}, '==', $exp_tax, "'tax' value in HASH same as expected: $exp_tax" );
    cmp_ok( $item->{duty}, '==', $exp_duty, "'duty' value in HASH same as expected: $exp_duty" );

    note "call the 'calculate_refund_charge_per_item' function and check the result";
    $item_clone{reason_id}  = delete $item_clone{_reason_id};
    my @values  = calculate_refund_charge_per_item( $domain->schema, \%item_clone, $ship_item, $ship_addr );
    cmp_ok( $values[0], '==', 0, "'got_refund' flag set to 0" );
    cmp_ok( $values[1] || 0, '==', -$exp_duty, "'charge_duty' as expected: ".(-$exp_duty) );  # these 2 values should
    cmp_ok( $values[2] || 0, '==', -$exp_tax, "'charge_tax' as expected: ".(-$exp_tax) );     # be positive versions
    cmp_ok( $values[3], '==', 1, "'num_exchange_items' set to 1" );
    cmp_ok( $item_clone{tax}, '==', $exp_tax, "'tax' value in HASH as expected: $exp_tax" );
    cmp_ok( $item_clone{duty}, '==', $exp_duty, "'duty' value in HASH as expected: $exp_duty" );

    # test the 'Order::Functions::Return::AddItem::_process_items'
    # function which is used when Manually Adding Exchange Items
    %item_clone = %{ $item };
    note "call the 'XTracker::Order::Functions::Return::AddItem::_process_items' function and check the result";
    my $item_args   = _mock_up_add_items_arguments( $domain, $ship_item, $ship_addr, \%item_clone, 'Add' );
    XTracker::Order::Functions::Return::AddItem::_process_items( $item_args );
    my $add_item    = $item_args->{data}{return_items}{ $ship_item->id };
    cmp_ok( $item_args->{data}{num_exchange_items}, '==', 1, "'num_exchange_items' value is 1" );
    cmp_ok( $add_item->{unit_price}, '==', 0, "'unit_price' value in HASH is 0" );
    cmp_ok( $add_item->{tax}, '==', $exp_tax, "'tax' value in HASH same as expected: $exp_tax" );
    cmp_ok( $add_item->{duty}, '==', $exp_duty, "'duty' value in HASH same as expected: $exp_duty" );
    cmp_ok( $item_args->{data}{charge_duty}, '==', -$exp_duty, "'charge_duty' as expected: ".(-$exp_duty) );  # these 2 values should
    cmp_ok( $item_args->{data}{charge_tax}, '==', -$exp_tax, "'charge_tax' as expected: ".(-$exp_tax) );      # be positive versions

    # test the 'Order::Functions::Return::ConvertToExchange::_get_tax_duty_charges'
    # function which is used when Manually Converting Items to an Exchange
    %item_clone = %{ $item };
    note "call the 'XTracker::Order::Functions::Return::ConvertToExchange::_get_tax_duty_charges' function and check the result";
    $item_args  = _mock_up_add_items_arguments( $domain, $ship_item, $ship_addr, \%item_clone, 'ConvertToExchange' );
    XTracker::Order::Functions::Return::ConvertToExchange::_get_tax_duty_charges( $item_args );
    my $conv_item   = $item_args->{data}{shipment_items}{ $ship_item->id };
    cmp_ok( $conv_item->{charge_tax}, '==', $exp_tax, "'charge_tax' value in HASH same as expected: $exp_tax" );
    cmp_ok( $conv_item->{charge_duty}, '==', $exp_duty, "'charge_duty' value in HASH same as expected: $exp_duty" );

    return;
}

# by default this will create a Dispatched Order
sub _create_an_order {
    my ( $num_pids, $channel )  = @_;

    my $schema  = Test::XTracker::Data->get_schema();

    $num_pids   ||= 2;
    $channel    ||= Test::XTracker::Data->channel_for_nap;

    my $dc_country  = config_var( 'DistributionCentre', 'country' );
    my $ship_country= $schema->resultset('Public::Country')
                                ->search( { country => { '!=' => $dc_country } } )
                                    ->first;

    note "Invoice Country : $dc_country";
    note "Shipping Country: ".$ship_country->country;

    my $invoice_address = Test::XTracker::Data->order_address( { address => 'create', country => $dc_country } );
    my $shipment_address= Test::XTracker::Data->order_address( { address => 'create', country => $ship_country->country } );

    my $currency    = $schema->resultset('Public::Currency')
                                ->search( { currency => config_var( 'Currency', 'local_currency_code' ) } )
                                    ->first;

    my ( $forget, $pids )  = Test::XTracker::Data->grab_products( {
            how_many    => $num_pids,
            how_many_variants => 2,
            channel     => $channel,
            ensure_stock_all_variants => 1,
    } );

    my $base    = {
            shipping_charge => 10,
            currency_id => $currency->id,
            invoice_address_id => $invoice_address->id,
            tenders => [ { type => 'card_debit', value => 10 + ( 100 * $num_pids ) } ],
        };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            attrs => [ map { price => 100, tax => 0, duty => 0 }, ( 1..$num_pids ) ],
        } );

    my $shipment    = $order->get_standard_class_shipment();
    $shipment->update( { shipment_address_id => $shipment_address->id } );
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id' } );

    ok($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr );
    note "Shipment Created: ".$shipment->id;

    return ( $order, $shipment, \@ship_items, $pids, $channel );
}

# helper to create X number of reservations
sub _create_reservations {
    my ( $number, $channel, $variant, $customer )   = @_;

    my @reservations;

    # get the Current Max Ordering Id for this Variant's Reservations
    my $current_max_ordering    = $variant->reservations->get_column('ordering_id')->max() || 0;

    foreach my $counter ( 1..$number ) {
        my $data = Test::XT::Data->new_with_traits(
                        traits => [
                            'Test::XT::Data::ReservationSimple',
                        ],
                    );

        $data->customer( $customer )        if ( defined $customer );       # use the same Customer if asked to
        $data->channel( $channel );
        $data->variant( $variant );                             # make sure all reservations are for the same SKU

        my $reservation = $data->reservation;
        $reservation->update( { ordering_id => $current_max_ordering + $counter } );    # prioritise each reservation

        note "Customer Id/Nr: ".$reservation->customer->id."/".$reservation->customer->is_customer_number;

        push @reservations, $reservation;
    }

    return @reservations;
}

# create 'return_country_refund_charge' records for a Country
sub _create_country_refund_charges {
    my ($country, $true_false, @types) = @_;

    foreach my $type ( @types ) {
        $country->create_related( 'return_country_refund_charges', {
                                                refund_charge_type_id   => $type,
                                                can_refund_for_return   => $true_false,
                                                no_charge_for_exchange  => $true_false,
                                        } );
    }

    return;
}

# updates a Countries '_create_country_refund_charges' records
# for a particular type(s) and/or flag
sub _update_country_refund_charges {
    my ($country, $field, $true_false, @types) = @_;

    foreach my $type ( @types ) {
        $country->return_country_refund_charges
                    ->search( { refund_charge_type_id => $type } )
                        ->first
                            ->update( { $field => $true_false } );
    }

    return;
}

# used to mock up arguments that would be passed into
# 'XTracker::Order::Functions::Return::AddItem::_process_items'
sub _mock_up_add_items_arguments {
    my ( $domain, $ship_item, $ship_addr, $item, $type )    = @_;

    $item->{selected}   = 1;
    # delete from the item un-wanted keys
    $item->{reason_id}  = delete $item->{_reason_id};
    foreach my $key ( qw( _tax _duty tax duty unit_price ) ) {
        delete  $item->{ $key };
    }

    my $args    = {
            dbh     => $domain->schema->storage->dbh,
            schema  => $domain->schema,
            data    => {
                num_return_items    => 0,
                num_exchange_items  => 0,
                charge_tax          => 0,
                charge_duty         => 0,
                return_items    => {
                    $ship_item->id  => $item,
                },
                shipment_items  => {
                    $ship_item->id  => { $ship_item->get_columns },
                },
                shipment_address=> $ship_addr,
            },
        };

    if ( $type eq "ConvertFromExchange" || $type eq "ConvertToExchange" ) {
        my $reason  = $domain->schema->resultset('Public::CustomerIssueType')
                                        ->find( delete $item->{reason_id} );
        $item->{reason} = $reason->description;
        foreach my $key ( qw( num_return_items num_exchange_items charge_tax charge_duty ) ) {
            delete $args->{data}{ $key };
        }
    }

    # mock up an 'XTracker::Handler' as that is
    # actually what is passed to '_process_items'
    my $mock_args   = Test::MockObject->new( $args );
    $mock_args->set_isa('XTracker::Handler');
    $mock_args->set_always( operator_id => $APPLICATION_OPERATOR_ID );
    $mock_args->set_always( schema => $domain->schema );
    $mock_args->set_always( dbh => $domain->schema->storage->dbh );

    return $mock_args;
}

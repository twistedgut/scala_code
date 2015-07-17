package Test::XTracker::Database::OrderPayment;

use NAP::policy     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
};

=head1 NAME

Test::XTracker::Database::OrderPayment

=head1 DESCRIPTION

Test functions in the 'XTracker::Database::OrderPayment' module:

    process_payment - (for notifying PSP of Exchanges only)


Please Note: There is another non 'Test::Class' test:

    t/20-units/database/process_payment.t

which tests the function 'process_payment' to make sure that the
PSP is called to Settle a payment and checks that the correct
Invoices have been created.

=cut

use Test::XTracker::Data;

use Test::XT::Data;

use XTracker::Constants::FromDB             qw( :return_item_status );

use XTracker::Database::OrderPayment        qw( process_payment );

use Mock::Quick;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    my $data = Test::XT::Data->new_with_traits( {
        traits => [ qw(
            Test::XT::Data::Order
            Test::XT::Data::Return
        ) ]
    } );
    $self->{data} = $data;
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin();

    my ( $channel, $pids ) = Test::XTracker::Data->grab_products( {
        how_many => 2,
        how_many_variants => 2,
        ensure_stock_all_variants => 1,
    } );

    $self->{channel} = $channel;
    $self->{pids}    = $pids;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback();
}


=head1 TESTS

=head2 test_process_payment_updates_the_basket_when_called_for_exchange_shipment

Tests that when 'process_payment' is called for an Exchange Shipment and the
Order's Payment Method requires it that the PSP is notified with the correct
Item Changes that have happened for the Exchange.

=cut

sub test_process_payment_updates_the_basket_when_called_for_exchange_shipment : Tests {
    my $self = shift;

    # end point on the PSP that should be used
    my $psp_end_point = Test::XTracker::Data->get_psp_end_point('Item Replacement');

    # Successful PSP Response
    my $psp_success_response = Test::XTracker::Data->get_general_psp_success_response();

    my $product_data = $self->{pids}[0];

    my $order_data = $self->{data}->dispatched_order(
        channel  => $self->{channel},
        products => [ $product_data ],
    );
    my $order         = $order_data->{order_object};
    my $shipment      = $order_data->{shipment_object};
    my $shipment_item = $shipment->shipment_items->first;

    # get the original Variant and then any
    # one of the Products other Variants
    my $orig_variant = $shipment_item->variant;
    my ( $new_variant ) = grep { $_->id != $orig_variant->id }
                            $product_data->{product}->variants->all;

    # make sure a Payment has been created on the Order
    $order->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    my $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    # set the payment as being Fulfilled so that 'process_payment'
    # doesn't try and take the money again
    $payment->update( { fulfilled => 1 } );

    my $return = $self->{data}->qc_passed_return( {
        shipment_id => $shipment->id,
        items => {
            $shipment_item->id => {
                type => 'Exchange',
                exchange_variant_id => $new_variant->id,
            },
        },
    } );

    # get details of the Exchange
    my $exchange_shipment = $return->exchange_shipment;
    my $exchange_item     = $exchange_shipment->shipment_items->first;
    my $return_item       = $exchange_item->return_item_exchange_shipment_item_ids->first;

    my %monitor_basket;
    my $basket_mock = $self->_mock_basket( \%monitor_basket );

    my %tests = (
        "Exchange Shipment - Make Succesful Request to Update the Basket" => {
            setup => {
                psp_to_be_notified => 1,
                shipment_id        => $exchange_shipment->id,
            },
            expect => {
                update_basket_called => 1,
                basket_params => [
                    { orig_item_id => $shipment_item->id, new_item_id => $exchange_item->id },
                ],
            },
        },
        "Exchange Shipment - Make an Unsuccesful Request to Update the Basket" => {
            setup => {
                psp_to_be_notified => 1,
                shipment_id        => $exchange_shipment->id,
                get_basket_to_die  => 1,
            },
            expect => {
                to_die => 1,
            },
        },
        "Exchange Shipment - Check no Basket update is sent when PSP doesn't need to be notified" => {
            setup => {
                psp_to_be_notified => 0,
                shipment_id        => $exchange_shipment->id,
            },
            expect => {
                update_basket_called => 0,
            },
        },
        "Standard Class Shipment with Payment Fulfilled - Check no Basket update sent even when PSP wants to be notified of Basket Changes" => {
            setup => {
                psp_to_be_notified => 1,
                shipment_id        => $shipment->id,
            },
            expect => {
                update_basket_called => 0,
            },
        }
    );

    TEST:
    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        %monitor_basket = ();

        if ( $setup->{psp_to_be_notified} ) {
            Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );
        }
        else {
            Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );
        }

        $monitor_basket{ask_to_die} = 1     if ( $setup->{get_basket_to_die} );

        if ( $expect->{to_die} ) {
            throws_ok {
                    process_payment( $self->schema, $setup->{shipment_id} );
                }
                qr/Couldn't Update PSP/i,
                "'process_payment' DIE'd with expected Error Message"
            ;
            next TEST;
        }

        my $order_nr;
        my $web_conf_section;

        lives_ok {
            ( $order_nr, $web_conf_section ) = process_payment( $self->schema, $setup->{shipment_id} );
        } "'process_payment' has run ok";
        is( $order_nr, $order->order_nr, "'process_payment' returned the Order Number" );
        is( $web_conf_section, $self->{channel}->business->config_section, "'process_payment' returned the Config Section" );

        if ( $expect->{update_basket_called} ) {
            ok( exists $monitor_basket{params_passed}, "Basket Update was Called" );
            cmp_deeply( $monitor_basket{params_passed}, bag( @{ $expect->{basket_params} } ), "and received the Correct Changes" )
                            or diag "ERROR - Basked Updated didn't receive the Correct Changes: " . p( $expect->{basket_params} );
        }
        else {
            ok( !exists $monitor_basket{params_passed}, "Basket Update wasn't Called" )
                            or diag "ERROR - Basket Update WAS Called: " . p( %monitor_basket );
        }
    }
}

#------------------------------------------------------------------------------

sub _mock_basket {
    my ( $self, $monitor_hash ) = @_;

    my $basket_mock = qtakeover 'XT::Domain::Payment::Basket' => (
        update_psp_with_item_changes => sub {
            my ( $self, $change_list ) = @_;

            $monitor_hash->{params_passed} = $change_list;

            if ( $monitor_hash->{ask_to_die} ) {
                die "TEST TOLD ME TO";
            }

            return 1;
        },
    );

    return $basket_mock;
}


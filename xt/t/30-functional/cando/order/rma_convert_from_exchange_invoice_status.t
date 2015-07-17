#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition export => qw( $distribution_centre );

=head2 Test Invoice Status after Converting an Exchange to a Return

This tests that after an Exchange has been Converted to being a Return the Invoice that is created
is at the correct Status which is 'Pending' before 'Returns QC' and 'Awaiting Authorisation' after.

=cut

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :renumeration_status
                                        :renumeration_type
                                    );

use Test::XT::Flow;


my $amq     = Test::XTracker::MessageQueue->new;

my $channel = Test::XTracker::Data->get_local_channel();
my @pids    = sort { $a->id <=> $b->id } map { $_->{product} } @{
        (
            Test::XTracker::Data->grab_products( {
                    channel => $channel,
                    how_many => 2,
                    how_many_variants => 2,
                    ensure_stock_all_variants => 1,
                } )
        )[1]
    };
# get All Variants for Products created
my @pid1_vars   = $pids[0]->variants->search( {}, { order_by => 'me.id' } )->all;
my @pid2_vars   = $pids[1]->variants->search( {}, { order_by => 'me.id' } )->all;

# use for Creating All Orders
my $items   = {
        $pid1_vars[1]->sku => { price => 250.00, tax => 0, duty => 0 },
        $pid2_vars[0]->sku => { price => 100.00, tax => 0, duty => 0 },
    };

my %invoice_type_to_id  = (
        card_debit  => $RENUMERATION_TYPE__CARD_DEBIT,
        card_refund => $RENUMERATION_TYPE__CARD_REFUND,
        store_credit=> $RENUMERATION_TYPE__STORE_CREDIT,
    );

my %tests   = (
        'Store Credit Order'=> {
                tenders => [ { type => 'store_credit', value => 350 } ],
                expected=> {
                        invoices => {
                                store_credit => 250,
                            },
                    },
            },
        'Credit Card Order' => {
                tenders => [ { type => 'card_debit', value => 350 } ],
                expected=> {
                        invoices => {
                                card_refund => 250,
                            },
                    },
            },
        'Store Credit & Credit Card Order'  => {
                tenders => [
                    { type => 'card_debit', value => 175 },
                    { type => 'store_credit', value => 175 },
                ],
                expected=> {
                        invoices => {
                                card_refund => 175,
                                store_credit=> 75,
                            },
                    },
            },
    );


my $framework   = Test::XT::Flow->new();
my $mech        = $framework->mech;
my $queue       = $mech->nap_order_update_queue_name();
$amq->clear_destination( $queue );

$framework->login_with_permissions( {
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Customer Care/Customer Search',
            'Customer Care/Order Search',
            'Customer Care/Returns Pending',
            'Goods In/Returns In',
            'Goods In/Returns QC',
            'Goods In/Putaway',
        ],
    },
    dept => 'Customer Care',
} );

TEST:
foreach my $label ( keys %tests ) {
    subtest $label => sub {
        my $test    = $tests{ $label };

        # set-up what is expected to be returned
        my $expected_invoices   = $test->{expected}{invoices};

        subtest "Test Converting an Exchange to a Return before Passing QC" => sub {
            my $order   = _create_order( $channel, $items, $test );
            my $shipment= $order->get_standard_class_shipment;
            $mech->order_nr( $order->order_nr );

            my $return;
            $mech->test_create_rma( $shipment, 'exchange' )
                ->test_exchange_pending( $return = $shipment->returns->not_cancelled->first )
                ->test_convert_from_exchange( $return );

            my $invoices = _check_invoice( $return, $expected_invoices, 'Pending' );

            # convert back to an Exchange
            $mech->test_convert_to_exchange( $return );
            _check_invoice_cancelled( $invoices );

            $mech->test_bookin_rma( $return )
                ->test_convert_from_exchange( $return );

            $invoices = _check_invoice( $return, $expected_invoices, 'Pending' );
        };


        # you can't convert a Return to an Exchange after the item
        # has been booked in so will have to create a fresh order

        subtest "Test Converting an Exchange to a Return After Passing QC" => sub {
            my $order      = _create_order( $channel, $items, $test );
            my $shipment   = $order->get_standard_class_shipment;
            $mech->order_nr( $order->order_nr );

            my $return;
            $mech->test_create_rma( $shipment, 'exchange' )
                ->test_exchange_pending( $return = $shipment->returns->not_cancelled->first )
                ->test_bookin_rma( $return )
                ->test_returns_qc_pass( $return )
                ->test_convert_from_exchange( $return );

            _check_invoice( $return, $expected_invoices, 'Completed' );
        };


        # TODO: get 'test_returns_putaway' to pass for all DCs
        return if ( $distribution_centre ne 'DC1' );

        subtest "Test Converting an Exchange to a Return After Putaway" => sub {
            my $order      = _create_order( $channel, $items, $test );
            my $shipment   = $order->get_standard_class_shipment;
            $mech->order_nr( $order->order_nr );

            my $return;
            $mech->test_create_rma( $shipment, 'exchange' )
                ->test_exchange_pending( $return = $shipment->returns->not_cancelled->first )
                ->test_bookin_rma( $return )
                ->test_returns_qc_pass( $return )
                ->test_returns_putaway( $return )
                ->test_convert_from_exchange( $return );

            _check_invoice( $return, $expected_invoices, 'Completed' );
        };
    };
}

done_testing;

#---------------------------------------------------------------------------------------

sub _create_order {
    my ( $channel, $items, $details )   = @_;

    my $order   = Test::XTracker::Data->create_db_order( {
                        items       => $items,
                        channel_id  => $channel->id,
                        tenders     => $details->{tenders},
                    } );

    return $order;
}

sub _check_invoice {
    my ( $return, $expected_invoices, $expected_status )    = @_;

    note "Testing Expected Invoices have been Created and at Status: '${expected_status}'";

    my $expected_invoice_count  = scalar( keys %{ $expected_invoices } );

    my $invoice_rs  = $return->discard_changes->renumerations->not_cancelled;
    cmp_ok( $invoice_rs->count, '==', $expected_invoice_count, "Expected number of Invoices created" );

    my ( $psp_flag_msg, $psp_test ) = ( $expected_status eq 'Completed' ? ( 'TRUE', 1 ) : ( 'FALSE', 0 ) );

    my %invoices    = map { $_->renumeration_type_id => $_ } $invoice_rs->all;
    while ( my ( $invoice_type, $invoice_value ) = each %{ $expected_invoices } ) {
        my $invoice = $invoices{ $invoice_type_to_id{ $invoice_type } };
        ok( defined $invoice, "Found an Invoice for Type: ${invoice_type}" );
        cmp_ok( $invoice->grand_total, '==', $invoice_value, "and the Value is as expected: ${invoice_value}" );

        if ( $expected_status eq 'Completed' && $invoice_type eq 'card_refund' ) {
            # As the PSP can't be mocked through the App.
            # the Status will be 'Awaiting Action' instead
            is( $invoice->renumeration_status->status, 'Awaiting Action', "and the Status is 'Awaiting Action' for a 'card_refund'" );
        }
        else {
            is( $invoice->renumeration_status->status, $expected_status, "and the Status is '${expected_status}'" );
        }
        cmp_ok( $invoice->sent_to_psp, '==', $psp_test, "and 'sent_to_psp' flag is ${psp_flag_msg}" );
    }

    return \%invoices;
}

sub _check_invoice_cancelled {
    my ( $invoices )    = @_;

    note "Testing Invoices have now been Cancelled";

    foreach my $invoice ( values %{ $invoices } ) {
        cmp_ok( $invoice->discard_changes->renumeration_status_id, '==', $RENUMERATION_STATUS__CANCELLED, "Invoice now Cancelled" );
    }

    return;
}

package Test::XTracker::Schema::Result::Public::Renumeration;

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Schema::Result::Public::Renumeration

=head1 DESCRIPTION

Tests various Methods & Result Set Methods for 'XTracker::Schema::Result::Public::Renumeration'

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Invoice;
use Test::XT::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :renumeration_class
                                        :renumeration_type
                                        :return_item_status
                                        :return_type
                                        :shipment_status
                                    );

use XTracker::Config::Local         qw(
                                        get_namespace_names_for_psp
                                    );

sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{channel} = Test::XTracker::Data->any_channel;
    $self->{domain}  = Test::XTracker::Data->returns_domain_using_dump_dir();
    $self->{schema}  = $self->{channel}->result_source->schema;

    # set-up some Hash Refs of Types & Statuses so that their
    # descriptions can be used in tests instead of Constants
    $self->{renumeration_types} = {
        map { $_->type => $_->id }
            $self->rs('Public::RenumerationType')->all
    };
    $self->{renumeration_statuses} = {
        map { $_->status => $_->id }
            $self->rs('Public::RenumerationStatus')->all
    };
    $self->{return_item_statuses} = {
        map { $_->status => $_->id }
            $self->rs('Public::ReturnItemStatus')->all
    };
}


sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{schema}->txn_begin;

    my $data = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Order',
        ],
    );

    my $order_details   = $data->dispatched_order( products => 2, channel => $self->{channel} );
    $self->{order}      = $order_details->{order_object};
    $self->{shipment}   = $order_details->{shipment_object};
    $self->{schema}     = $self->{shipment}->result_source->schema;
    ok( $self->{shipment}, 'created shipment ' . $self->{shipment}->id );
    $self->{shipment_items} = [
        $self->{shipment}->shipment_items->search( {}, { order_by => 'id' } )->all
    ];
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;

    $self->{schema}->txn_rollback;

}

=head1 TESTS

=head2 test_get_reason_for_display

Tests the 'get_reason_for_display' method to make sure
that a Renumeration Reason is returned when available,
if not then the Class should be returned.

=cut

sub test_get_reason_for_display : Tests {
    my $self = shift;

    my $shipment = $self->{shipment};

    my $reason = $self->rs('Public::RenumerationReason')
        ->get_compensation_reasons
        ->search(undef, {order_by => 'id', rows => 1})
        ->single;

    my @tests = (
        ['Order Class Invoice' => {
            class_id    => $RENUMERATION_CLASS__ORDER,
            enabled     => 1,
            expect      => 'Order',
        }],
        ['Cancellation Class Invoice' => {
            class_id    => $RENUMERATION_CLASS__CANCELLATION,
            enabled     => 1,
            expect      => 'Cancellation',
        }],
        ['Return Class Invoice' => {
            class_id    => $RENUMERATION_CLASS__RETURN,
            enabled     => 1,
            expect      => 'Return',
        }],
        ['Gratuity Class Invoice With a Reason' => {
            class_id    => $RENUMERATION_CLASS__GRATUITY,
            enabled     => 1,
            reason      => $reason,
            expect      => $reason->reason,
        }],
        ['Gratuity Class Invoice With a DISABLED Reason' => {
            class_id    => $RENUMERATION_CLASS__GRATUITY,
            enabled     => 0,
            reason      => $reason,
            expect      => $reason->reason . ' (Disabled)',
        }],
        ['Gratuity Class Invoice Without a Reason' => {
            class_id    => $RENUMERATION_CLASS__GRATUITY,
            enabled     => 1,
            expect      => 'Gratuity',
        }],
    );

    foreach my $test_data ( @tests ) {
        my ( $label, $test ) = @$test_data;
        subtest $label => sub {
            $reason->update({ enabled => $test->{enabled} });
            my $invoice = Test::XTracker::Data::Invoice->create_invoice( {
                shipment    => $shipment,
                class_id    => $test->{class_id},
                ( $test->{reason} ? ( reason_id => $test->{reason}->id ) : () ),
            } );

            my $got = $invoice->get_reason_for_display;
            is( $got, $test->{expect}, "Reason returned is as Expected: '$test->{expect}'" );
        };
    }
}

=head2 test__release_exchange_shipment

This tests the private method '_release_exchange_shipment' which gets called from the
public method 'refund_to_customer'. All though this is a private Method it is still
worth testing individually as the logic it uses lends it'self to a separate unit test.

The 'refund_to_customer' method is tested in 't/20-units/schema/renumeration.t'

=cut

sub test__release_exchange_shipment :Tests {
    my $self = shift;

    my $shipment   = $self->{shipment};
    my $ship_items = $self->{shipment_items};

    # want a Return with one Return Item & one Exchange Item
    my $items = {
        $ship_items->[0]->id => {
            type      => 'Return',
            reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
        },
        $ship_items->[1]->id => {
            type      => 'Exchange',
            reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
            exchange_variant => $ship_items->[1]->variant_id,
        },
    };
    # create the Return to be used by the tests that
    # should also have an Exchange Shipment with it
    my $return = $self->{domain}->create( {
        operator_id     => $APPLICATION_OPERATOR_ID,
        shipment_id     => $shipment->id,
        pickup          => 0,
        refund_type_id  => $RENUMERATION_TYPE__CARD_REFUND,
        return_items    => $items,
    } );
    my $exchange_shipment = $return->exchange_shipment;


    my @tests = (
        ["No Return for a Renumeration, nothing happens" => {
            setup => {
                create_renum => {
                    'Card Refund' => 'Completed',
                },
                no_link_to_return => 1,
            },
            expect => {
                exchange_shipment_status => 'Exchange Hold',
            },
        }],
        ["Refund Renumeration Complete, but Debit Renumeration NOT, Exchange should remain on Exchange Hold" => {
            setup => {
                create_renum => {
                    'Card Refund' => 'Completed',
                    'Card Debit'  => 'Awaiting Authorisation',
                },
                renum_to_use => 'Card Refund',
                items => {
                    Return   => 'Passed QC',
                    Exchange => 'Passed QC',
                },
            },
            expect => {
                exchange_shipment_status => 'Exchange Hold',
            },
        }],
        ["Refund Renumeration Complete, Debit Renumeration NOT & Exchange Item NOT QC'd, Exchange should remain on Exchange Hold" => {
            setup => {
                create_renum => {
                    'Card Refund' => 'Completed',
                    'Card Debit'  => 'Awaiting Authorisation',
                },
                renum_to_use => 'Card Refund',
                items => {
                    Return   => 'Passed QC',
                    Exchange => 'Failed QC - Awaiting Decision',
                },
            },
            expect => {
                exchange_shipment_status => 'Exchange Hold',
            },
        }],
        ["Debit Renumeration Complete but Exchange Item NOT QC'd, Exchange should be on Return Hold" => {
            setup => {
                create_renum => {
                    'Card Debit' => 'Completed',
                },
                items => {
                    Return   => 'Passed QC',
                    Exchange => 'Booked In',
                },
            },
            expect => {
                exchange_shipment_status => 'Return Hold',
            },
        }],
        ["Debit Renumeration Complete & Exchange Item QC'd, Exchange should now be Processing" => {
            setup => {
                create_renum => {
                    'Card Debit' => 'Completed',
                },
                items => {
                    Return   => 'Booked In',
                    Exchange => 'Passed QC',
                },
            },
            expect => {
                exchange_shipment_status => 'Processing',
            },
        }],
        ["Refund Renumeration Complete and Debit Renumeration Cancelled, Exchange should now be Processing" => {
            setup => {
                create_renum => {
                    'Card Refund' => 'Completed',
                    'Card Debit'  => 'Cancelled',
                },
                renum_to_use => 'Card Refund',
                items => {
                    Return   => 'Passed QC',
                    Exchange => 'Passed QC',
                },
            },
            expect => {
                exchange_shipment_status => 'Processing',
            },
        }],
        ["Refund Renumeration Complete and Debit Renumeration Complete, but Exchange Item not Returned, Exchange should go to Return Hold" => {
            setup => {
                create_renum => {
                    'Card Refund' => 'Completed',
                    'Card Debit'  => 'Completed',
                },
                renum_to_use => 'Card Refund',
                items => {
                    Return   => 'Passed QC',
                    Exchange => 'Awaiting Return',
                },
            },
            expect => {
                exchange_shipment_status => 'Return Hold',
            },
        }],
    );

    foreach my $test_data ( @tests ) {
        my ( $label, $test ) = @$test_data;
        subtest $label => sub {
            my $setup   = $test->{setup};
            my $expect  = $test->{expect};

            $self->_reset_return( $return );
            my $renum_to_use = $self->_setup_return( $return, $setup );

            $renum_to_use->_release_exchange_shipment( $APPLICATION_OPERATOR_ID );

            $exchange_shipment->discard_changes;
            is( $exchange_shipment->shipment_status->status, $expect->{exchange_shipment_status},
                            "after call to '_release_exchange_shipment' - Exchange Shipment Status is as Expected" );
        };
    }
}

=head2 test_format_items_for_refund

Test the C<format_items_for_refund> method.

Run the following test scenarios, confirming the correct data is returned for
each:

    * No renumeration items, no shipping cost.
        - Should be an empty ArrayRef.
    * No renumeration items, but with a shipping cost.
        - Should just return an ArrayRef with a single Shipping SKU.
    * With renumeration items and no shipping cost.
        - Should just return an ArrayRef of the Renumeration Items.
    * With renumeration items and a shipping cost.
        - Should return an ArrayRef with both Renumeration Items and a single
          Shipping SKU.

=cut

sub test_format_items_for_refund : Tests {
    my $self = shift;

    my %tests = (
        'No renumeration items, no shipping cost' => {
            create_renumeration_items   => 0,
            has_shipping_charge         => 0,
        },
        'No renumeration items, but with a shipping cost' => {
            create_renumeration_items   => 0,
            has_shipping_charge         => 1,

        },
        'With renumeration items and no shipping cost' => {
            create_renumeration_items   => 1,
            has_shipping_charge         => 0,

        },
        'With renumeration items and a shipping cost' => {
            create_renumeration_items   => 1,
            has_shipping_charge         => 1,

        },
    );

    while ( my ( $name, $test ) = each %tests ) {
        subtest $name => sub {

            my $renumeration    = Test::XTracker::Data->create_renumeration( $self->{shipment} );
            my $currency        = $renumeration->currency->currency;
            my @expected;

            if ( $test->{create_renumeration_items} ) {

                # Create some renumeration items linked to the shipment.
                Test::XTracker::Data->create_renumeration_item( $renumeration, $_->id )
                    foreach $self->{shipment}->shipment_items->all;

                # Add all the renumeration items to the list of expected items.
                foreach my $renumeration_item ( $renumeration->renumeration_items->all ) {
                    my $variant     = $renumeration_item->shipment_item->variant;
                    my $price       = $renumeration_item->unit_price;
                    my $vat         = $renumeration_item->tax;
                    my $tax         = $renumeration_item->duty;
                    push @expected, {
                        sku     => $variant->sku,
                        name    => $variant->product->name,
                        amount  => ( $price + $vat + $tax ) * 100,
                        vat     => $vat * 100,
                        tax     => $tax * 100,
                    };
                }

            }

            if ( $test->{has_shipping_charge} ) {

                # Add the shipping to the list of expected items.
                my $names_for_psp = get_namespace_names_for_psp( $self->{schema} );
                push @expected, {
                    sku     => $names_for_psp->{shipping_sku},
                    name    => $names_for_psp->{shipping_name},
                    amount  => 1234,
                    vat     => 0,
                    tax     => 0,
                };
                # Set the shipping to have a value.
                $renumeration->update({ shipping => 12.34 });
            } else {
                # Set the shipping to have no value.
                $renumeration->update({ shipping => 0 });
            }

            cmp_deeply( $renumeration->format_items_for_refund, \@expected,
                'The list of items to be refunded is correct' );

        }
    }

}

#-------------------------------------------------------------------

# reset the return to be ready for another test
sub _reset_return {
    my ( $self, $return ) = @_;

    $return->discard_changes;

    $return->link_return_renumerations->delete;
    $return->renumerations->search_related('renumeration_items')->delete;
    $return->renumerations->delete;

    my $shipment = $return->shipment;
    my $renum_rs = $shipment->renumerations->search( { renumeration_class_id => $RENUMERATION_CLASS__RETURN } );
    $renum_rs->search_related('renumeration_items')->delete;

    $return->return_items->update( {
        return_item_status_id => $RETURN_ITEM_STATUS__AWAITING_RETURN,
    } );

    $return->exchange_shipment->update( {
        shipment_status_id => $SHIPMENT_STATUS__EXCHANGE_HOLD,
    } );

    $return->discard_changes;

    return;
}

# change the Return and the Exchange Shipment
# according to how a test wants its data set-up
sub _setup_return {
    my ( $self, $return, $setup ) = @_;

    my $shipment = $return->shipment;

    my $renum_types    = $self->{renumeration_types};
    my $renum_statuses = $self->{renumeration_statuses};
    my $item_statuses  = $self->{return_item_statuses};

    my @renums;
    while ( my ( $type, $status ) = each %{ $setup->{create_renum} } ) {
        my $renum = $shipment->create_related( 'renumerations', {
            renumeration_class_id  => $RENUMERATION_CLASS__RETURN,
            renumeration_type_id   => $renum_types->{ $type },
            renumeration_status_id => $renum_statuses->{ $status },
            shipping               => 10,       # just a nominal amount
            invoice_nr             => '',
        } );

        $return->create_related('link_return_renumerations', {
            renumeration_id => $renum->id,
        } )     unless ( $setup->{no_link_to_return} );

        push @renums, $renum;
    }

    my $refund_item_rs   = $return->return_items->search( { return_type_id => $RETURN_TYPE__RETURN } );
    my $exchange_item_rs = $return->return_items->search( { return_type_id => $RETURN_TYPE__EXCHANGE } );

    if ( my $item_status = $setup->{items}{Return} ) {
        $refund_item_rs->update( { return_item_status_id => $item_statuses->{ $item_status } } );
    }
    if ( my $item_status = $setup->{items}{Exchange} ) {
        $exchange_item_rs->update( { return_item_status_id => $item_statuses->{ $item_status } } );
    }

    return $renums[0]       if ( scalar( @renums ) == 1 );

    my ( $renum_to_use ) = grep { $_->renumeration_type->type eq $setup->{renum_to_use} }
                                    @renums;

    return $renum_to_use;
}


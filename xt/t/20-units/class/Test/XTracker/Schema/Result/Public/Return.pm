package Test::XTracker::Schema::Result::Public::Return;

use NAP::policy     qw( test );

BEGIN { use parent "NAP::Test::Class" }

=head1 NAME

Test::XTracker::Schema::Result::Public::Return

=head1 DESCRIPTION

Tests the C<XTracker::Schema::Result::Public::Return> class.

=cut

BEGIN {

    use_ok 'Test::XTracker::Data';
    use_ok 'Test::XT::Data';

    use_ok 'XTracker::Constants', qw(
        :application
    );

    use_ok 'XTracker::Constants::FromDB', qw(
        :return_status
        :renumeration_type
        :shipment_status
        :shipment_item_status
        :return_type
        :renumeration_status
        :return_item_status
    );

}

# Global Test Startup
sub test_startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{channel} = Test::XTracker::Data->any_channel;
    $self->{domain}  = Test::XTracker::Data->returns_domain_using_dump_dir;

    $self->{customer_issue_type} = $self
        ->schema
        ->resultset('Public::CustomerIssueType')
        ->search( {
            pws_reason => { '!=' => undef },
        } );

    isa_ok( $self->{channel}, 'XTracker::Schema::Result::Public::Channel' );
    isa_ok( $self->{domain}, 'XT::Domain::Returns' );
    isa_ok( $self->{customer_issue_type}, 'XTracker::Schema::ResultSet::Public::CustomerIssueType' );

}

# Individual Test Startup
sub test_setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->SUPER::setup;

    # Start the transaction.
    $self->schema->txn_begin;

    # Get two products.
    my ( undef, $pids ) = Test::XTracker::Data->grab_products( {
        force_create => 1,
        channel      => $self->{channel},
        how_many     => 2,
    } );

    isa_ok( $pids, 'ARRAY' );

    # Create an order with two items.
    my ( $order ) = Test::XTracker::Data->create_db_order( {
        pids  => $pids,
        base  => {
            shipment_status      => $SHIPMENT_STATUS__DISPATCHED,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__DISPATCHED,
            create_renumerations => 1,
            tenders              => [
                {
                    type  => 'card_debit',
                    value => 760,
                },
            ],
        },
        attrs => [
            { price => 500, tax => 50, duty => 50 },
            { price => 250, tax => 25, duty => 25 },
        ],
    } );

    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );

    my $shipment = $order->get_standard_class_shipment;
    my ( $item1, $item2 ) = $shipment->shipment_items->all;

    isa_ok( $shipment, 'XTracker::Schema::Result::Public::Shipment' );
    isa_ok( $item2, 'XTracker::Schema::Result::Public::ShipmentItem' );
    isa_ok( $item2, 'XTracker::Schema::Result::Public::ShipmentItem' );

    # Create a return with one 'return' and one 'exchange'.
    my $return = $self->{domain}->create( {
        operator_id     => $APPLICATION_OPERATOR_ID,
        shipment_id     => $shipment->id,
        pickup          => 0,
        refund_type_id  => $RENUMERATION_TYPE__CARD_REFUND,
        return_items    => {
            $item1->id => {
                type      => 'Return',
                reason_id => $self->{customer_issue_type}->first->id,
            },
            $item2->id => {
                type             => 'Exchange',
                reason_id        => $self->{customer_issue_type}->first->id,
                exchange_variant => $item2->variant_id,
            },
        },
    } );

    isa_ok( $return, 'XTracker::Schema::Result::Public::Return' );
    note "Return Created - RMA: " . $return->rma_number;

    $self->{shipment_item_1} = $item1;
    $self->{shipment_item_2} = $item2;
    $self->{return}          = $return;
    $self->{renumeration}    = $return->renumerations->first;

    $self->{return_item} = $return->return_items->find( {
        shipment_item_id => $item1->id
    } );

    $self->{return_renumeration_item} = $self->{renumeration}->renumeration_items->find( {
        shipment_item_id => $item1->id
    } );

    $self->{exchange_item} = $return->return_items->find( {
        shipment_item_id => $item2->id
    } );

    $self->{exchange_renumeration_item} = $self->{renumeration}->renumeration_items->find( {
        shipment_item_id => $item2->id
    } );

}

# done everytime after each Test method has run
sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;

    # rollback changes done in a test
    # so they don't affect the next test
    $self->schema->txn_rollback;
}

sub test__reverse_return :Tests {
    my ($self) = @_;

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 2,
    });
    my $return_row = Test::XTracker::Data->create_rma({
        items => {
            map {
                $_->{sku} => { },
            } @$pids,
        }
    }, $pids);

    # create Renumerations using all Statuses, then later make
    # sure only the 'Awaiting Action' renumeration gets updated
    my %renumerations = map {
        $_->status => Test::XTracker::Data->create_renumeration( $return_row->shipment(), {
            renumeration_status_id => $_->id,
            return_row             => $return_row,
        } )
    } $self->rs('Public::RenumerationStatus')->all;
    my $awaiting_action_renumeration = delete $renumerations{'Awaiting Action'};
    note('Created a shipment, with a return, and renumerations: ' . $return_row->id);

    my @items = $return_row->return_items();
    ok($return_row->reverse_return({
        operator_id     => Test::XTracker::Data->get_application_operator_id(),
        return_items    => \@items,
    }), 'reverse_return() returns ok');
    is($return_row->return_status_id(), $RETURN_STATUS__PROCESSING,
        'return now has a status of "Processing"');

    # check Awaiting Action Renumeration
    $awaiting_action_renumeration->discard_changes;
    cmp_ok( $awaiting_action_renumeration->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING,
                "'Awaiting Action' renumeration now has a status of 'Pending'" );

    # check the rest of the Renumerations haven't changed Status
    while ( my ( $status, $renumeration ) = each %renumerations ) {
        $renumeration->discard_changes;
        is( $renumeration->renumeration_status->status, $status,
                "'${status}' renumeration's status is still '${status}'" );
    }
}

sub test_get_total_charges_for_exchange_items : Tests {
    my $self = shift;

    $self->do_tests( 'get_total_charges_for_exchange_items' => {
        'Not Exchange' => {
            setup => {
                exchange_item => { return_type_id => $RETURN_TYPE__RETURN },
            },
            expected => {
               total_charge     => 0,
               total_duty       => 0,
               total_tax        => 0,
               total_unit_price => 0,
            },
         },
        'Cancelled Renumeration' => {
            setup => {
                renumeration => { renumeration_status_id => $RENUMERATION_STATUS__CANCELLED },
            },
            expected => {
               total_charge     => 0,
               total_duty       => 0,
               total_tax        => 0,
               total_unit_price => 0,
            },
        },
        'Cancelled Return Item' => {
            setup => {
                exchange_item => { return_item_status_id => $RETURN_ITEM_STATUS__CANCELLED },
            },
            expected => {
               total_charge     => 0,
               total_duty       => 0,
               total_tax        => 0,
               total_unit_price => 0,
            },
        },
        'Negative' => {
            setup => {
                exchange_renumeration_item => { unit_price => -10, tax => -10, duty => -10 },
            },
            expected => {
               total_charge     => 30,
               total_duty       => 10,
               total_tax        => 10,
               total_unit_price => 10,
            },
        },
        'Positive' => {
            setup => {
                exchange_renumeration_item => { unit_price => 10, tax => 10, duty => 10 },
            },
            expected => {
               total_charge     => 30,
               total_duty       => 10,
               total_tax        => 10,
               total_unit_price => 10,
            },
        },
    } );

}

sub test_get_debit_charges_for_exchange_items : Tests {
    my $self = shift;

    $self->do_tests( 'get_debit_charges_for_exchange_items' => {
        'Not Exchange' => {
            setup => {
                exchange_item => { return_type_id => $RETURN_TYPE__RETURN },
            },
            expected => {
               total_charge     => 0,
               total_duty       => 0,
               total_tax        => 0,
               total_unit_price => 0,
            },
         },
        'Cancelled Renumeration' => {
            setup => {
                renumeration => { renumeration_status_id => $RENUMERATION_STATUS__CANCELLED },
            },
            expected => {
               total_charge     => 0,
               total_duty       => 0,
               total_tax        => 0,
               total_unit_price => 0,
            },
        },
        'Cancelled Return Item' => {
            setup => {
                exchange_item => { return_item_status_id => $RETURN_ITEM_STATUS__CANCELLED },
            },
            expected => {
               total_charge     => 0,
               total_duty       => 0,
               total_tax        => 0,
               total_unit_price => 0,
            },
        },
        'Not Card Debit' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__STORE_CREDIT },
            },
            expected => {
               total_charge     => 0,
               total_duty       => 0,
               total_tax        => 0,
               total_unit_price => 0,
            },
        },
        'Card Debit' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT },
                exchange_renumeration_item => { unit_price => 10, tax => 10, duty => 10 },
            },
            expected => {
               total_charge     => 30,
               total_duty       => 10,
               total_tax        => 10,
               total_unit_price => 10,
            },
        },
    } );

}

sub test_has_at_least_one_debit_card_renumeration : Tests {
    my $self = shift;

    $self->do_tests( 'has_at_least_one_debit_card_renumeration' => {
        'Not Exchange' => {
            setup => {
                exchange_item => { return_type_id => $RETURN_TYPE__RETURN },
            },
            expected => 0,
         },
        'Cancelled Renumeration' => {
            setup => {
                renumeration => { renumeration_status_id => $RENUMERATION_STATUS__CANCELLED },
            },
            expected => 0,
        },
        'Cancelled Return Item' => {
            setup => {
                exchange_item => { return_item_status_id => $RETURN_ITEM_STATUS__CANCELLED },
            },
            expected => 0,
        },
        'Not Card Debit' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__STORE_CREDIT },
            },
            expected => 0,
        },
        'Card Debit (all zero value)' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT },
                return_renumeration_item => { unit_price => 0, tax => 0, duty => 0 },
                exchange_renumeration_item => { unit_price => 0, tax => 0, duty => 0 },
            },
            expected => 0,
        },
        'Card Debit (only unit_price non zero)' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT },
                return_renumeration_item => { unit_price => 10, tax => 0, duty => 0 },
                exchange_renumeration_item => { unit_price => 10, tax => 0, duty => 0 },
            },
            expected => 1,
        },
        'Card Debit (only tax non zero)' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT },
                return_renumeration_item => { unit_price => 0, tax => 10, duty => 0 },
                exchange_renumeration_item => { unit_price => 0, tax => 10, duty => 0 },
            },
            expected => 1,
        },
        'Card Debit (only duty non zero)' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT },
                return_renumeration_item => { unit_price => 0, tax => 0, duty => 10 },
                exchange_renumeration_item => { unit_price => 0, tax => 0, duty => 10 },
            },
            expected => 1,
        },
        'Card Debit (all non zero)' => {
            setup => {
                renumeration => { renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT },
                return_renumeration_item => { unit_price => 10, tax => 10, duty => 10 },
                exchange_renumeration_item => { unit_price => 10, tax => 10, duty => 10 },
            },
            expected => 1,
        },
    } );

}

sub update_tables {
    my ($self,  $tables ) = @_;

    # Clear any stored data.
    $self->{original_table_data} = {};

    while ( my ( $table, $columns ) = each %$tables ) {
    # For each table given.

        # Make a copy of the current values for the columns
        # we're about to update.
        $self->{original_table_data}->{ $table } = {
            map { $_ => $self->{ $table }->$_ }
            keys %$columns
        };

        # Update the table.
        $self->{ $table }->update( $columns );

    }

}

sub restore_tables {
    my $self = shift;

    # Restore the original_table_data table data.
    $self->{ $_ }->update( $self->{original_table_data}->{ $_ } )
        foreach keys %{ $self->{original_table_data} };

}

sub do_tests {
    my ($self,  $method, $tests ) = @_;

    while ( my ( $name, $test ) = each %$tests ) {

        # Update the tables as defined by the test.
        $self->update_tables( $test->{setup} );

        # Call the method.
        my $result = $self->{return}->$method;

        if ( ref $test->{expected} ) {
        # If we expect some kind of reference.

            # Make sure it's the right type of reference.
            isa_ok( $result, ref( $test->{expected} ), "Result of $method" );

            # Because we expect a reference, do a deep comparison.
            cmp_deeply(
                $result,
                $test->{expected},
                "$method returns the correct result for '$name'"
             );

        } else {

            # Otherwise, if it's not a reference, just do a
            # normal comparison.
            cmp_ok(
                $result,
                '==',
                $test->{expected},
                "$method returns the correct result for '$name'"
            );

        }

        # Now restore the tables to how they where before the test. We can't do
        # this in a transaction, because we're already in a one and a rollback
        # in a nested transaction is not allowed.
        $self->restore_tables;

    }
}

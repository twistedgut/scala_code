package Test::XT::Service::Order::AuthorisePayment;

use NAP::policy qw( tt test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::XT::Service::Order::AuthorisePayment

=head1 DESCRIPTION

This tests the 'XT::Service::Order::AuthorisePayment' class which is used to create new Pre-Auths for
Orders and is used to support the 'Pre-Authorise Order' left hand menu option on the Order View page.

=cut

use XTracker::Constants             qw( :psp_default :application );
use XTracker::Constants::FromDB     qw(
    :orders_payment_method_class
    :shipment_status
    :shipment_hold_reason
    :note_type
);

use Test::XTracker::Data::Order;

use Test::XTracker::Mock::Handler;
use Test::XTracker::Mock::PSP;


sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup();

    my $default_payment_method   = $self->rs('Orders::PaymentMethod')->find( {
        payment_method  => $PSP_DEFAULT_PAYMENT_METHOD,
    } );
    my $third_party_payment_method = $self->rs('Orders::PaymentMethod')->search( {
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
    } )->first;
    $self->{default_payment_method}     = $default_payment_method;
    $self->{third_party_payment_method} = $third_party_payment_method;

    # find an Operator that isn't Application or 'it.god'
    my $operator = $self->rs('Public::Operator')->search( {
        id          => { '!='       => $APPLICATION_OPERATOR_ID },
        username    => { 'NOT ILIKE' => '%it%god%' },
        name        => { 'NOT ILIKE' => '%disabled%' },
    } )->first;
    $self->{operator} = $operator;

    use_ok( 'XT::Service::Order::AuthorisePayment' );

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state

    # Make sure the PSP always returns a success.
    Test::XTracker::Mock::PSP->set__get_card_details_status__response__success;

}

sub setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->SUPER::setup();

    $self->{order_details} = Test::XTracker::Data::Order->create_new_order;
    my $order = $self->{order_details}{order_object};
    # remove any 'orders.payment' records
    $order->payments->delete;
    $order->replaced_payments->delete;

    $self->{order}    = $order->discard_changes;
    $self->{shipment} = $self->{order_details}{shipment_object}->discard_changes;
    ok( $self->{shipment}, 'created shipment ' . $self->{shipment}->id );
    $self->{shipment}->update( {
        shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
    } );

    $self->{create_payment_args} = Test::XTracker::Data->get_new_psp_refs;
    $self->{create_payment_args}{payment_method} = $self->{default_payment_method};
    # get rid of the 'settle_ref'
    delete $self->{create_payment_args}{settle_ref};
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown();

    Test::XTracker::Mock::PSP->use_all_original_methods();
}

=head1 TESTS

=head2 test_original_payment_is_stored_when_getting_new_preauth

This tests that when a new Pre-Auth is requested then before being updated the
original 'orders.payment' record is stored in the 'orders.replaced_payment' table.

=cut

sub test_original_payment_is_stored_when_getting_new_preauth : Tests {
    my $self = shift;

    my $order = $self->{order};

    my @tests = (
        ["Check 'replaced_payment' record gets created correctly" => {
            setup => {
                payment => {
                    payment_method  => $self->{third_party_payment_method},
                },
            },
            expect => {
                order_note => 1,
            },
        }],
        ["Check 'valid' & 'fulfilled' flags are correct in 'replaced_payment' when initially TRUE & FALSE respectively" => {
            setup => {
                payment => {
                    payment_method  => $self->{default_payment_method},
                    valid           => 1,
                    fulfilled       => 0,
                },
            },
        }],
        ["Check 'valid' & 'fulfilled' flags are correct in 'replaced_payment' when initially FALSE & TRUE respectively" => {
            setup => {
                payment => {
                    payment_method  => $self->{third_party_payment_method},
                    valid           => 0,
                    fulfilled       => 1,
                },
            },
            expect => {
                order_note => 1,
            },
        }],
        ["Check that if a 'settle_ref' is present on original that it is transfered to the 'replaced_payment' correctly" => {
            setup => {
                payment => {
                    payment_method  => $self->{default_payment_method},
                    settle_ref      => 'SETTLE_1234',
                },
            },
        }],
        ["Check when there was NO original Payment record that the process doesn't DIE" => {
            setup => {
                payment => undef,
            },
        }],
        ["Check when a second Pre-Auth is asked for that there are two 'replaced_payment' records created" => {
            setup => {
                payment => {
                    payment_method  => $self->{third_party_payment_method},
                },
                repeat => 1,
            },
            expect => {
                order_note => 1,
            },
        }],
        ["Check that when a Payment has Log records for it, that they've been moved to the Replaced Payment" => {
            setup => {
                payment => {
                    payment_method  => $self->{default_payment_method},
                },
                create_logs => {
                    'preauth_cancellations' => {
                        cancelled             => 1,
                        preauth_ref_cancelled => $self->{create_payment_args}{preauth_ref},
                        context               => 'test',
                        message               => 'test message',
                        operator_id           => $self->{operator}->id,
                    },
                    'fulfilled_changes' => {
                        new_state         => 1,
                        operator_id       => $self->{operator}->id,
                        reason_for_change => 'test reason',
                    },
                    'valid_changes' => { new_state => 1 },
                },
            },
            expect => {
                logs_moved => 1,
            },
        }],
    );

    TEST:
    foreach my $test_data ( @tests ) {
        my ( $label, $test ) = @$test_data;
        subtest $label => sub {
            my $setup   = $test->{setup};
            my $expect  = $test->{expect};

            $order->discard_changes->payments->delete;
            $order->replaced_payments->delete;
            $order->order_notes->delete;

            my $payment;
            my $orig_payment;

            if ( $setup->{payment} ) {
                $self->{create_payment_args}{payment_method} = delete $setup->{payment}{payment_method};
                $payment = Test::XTracker::Data->create_payment_for_order(
                    $order,
                    $self->{create_payment_args},
                );
                $payment->update( $setup->{payment} )       if ( scalar keys %{ $setup->{payment} } );

                # the above record will be overwritten so store
                # all the details in a HASH to be checked against
                # later, but the 'id' can be ignored
                $orig_payment = _payment_as_hash( $payment );
            }

            my @log_relations_created;
            if ( my $logs_to_create = $setup->{create_logs} ) {
                foreach my $log_relation ( keys %{ $logs_to_create } ) {
                    $payment->create_related( "log_payment_${log_relation}", $logs_to_create->{ $log_relation } );
                    push @log_relations_created, $log_relation;
                }
                $payment->discard_changes;
            }

            $self->_make_full_cycle_request( $order );

            # if no Original Payment then no point in continuing
            return if ( !$setup->{payment} );

            # make sure we've got the latest
            $order->discard_changes;
            $payment->discard_changes;

            # 'orders.payment' should always be updated to 'Credit Card'
            cmp_ok( $payment->payment_method_id, '==', $self->{default_payment_method}->id,
                            "Original Payment Record's Payment Method is now a Credit Card" );
            isnt( $payment->psp_ref, $orig_payment->{psp_ref}, "PSP Ref. has been Updated" );
            isnt( $payment->preauth_ref, $orig_payment->{psp_ref}, "Pre-Auth Ref. has been Updated" );
            cmp_ok( $payment->valid, '==', 1, "'valid' flag is set to TRUE" );

            cmp_ok( $order->replaced_payments->count, '==', 1,
                            "One 'orders.replaced_payment' record was created" );
            my $replaced_payment = $order->replaced_payments->first;
            my %replaced_payment = $replaced_payment->get_columns;
            cmp_deeply( \%replaced_payment, superhashof( $orig_payment ), "and Replaced Payment matches the Original" );

            # check that an Order Note has/hasn't been created
            if ( $expect->{order_note} ) {
                cmp_ok( $order->order_notes->count, '==', 1, "One Order Note was Created" );
                my $note = $order->order_notes->first;
                cmp_ok( $note->note_type_id, '==', $NOTE_TYPE__FINANCE,
                                    "and the Note Type is for Finance" );
                cmp_ok( $note->operator_id, '==', $APPLICATION_OPERATOR_ID,
                                    "and the Note Operator is App. User" );

                my $original_method = $self->{third_party_payment_method}->payment_method;
                my $new_method      = $self->{default_payment_method}->payment_method;
                like( $note->note, qr/Payment Method.*from '${original_method}' to '${new_method}'/i,
                                    "and the actual Note was as Expected" );
            }
            else {
                cmp_ok( $order->order_notes->count, '==', 0, "No Order Note was Created" );
            }

            if ( $expect->{logs_moved} ) {
                foreach my $log_relation ( @log_relations_created ) {
                    note "Checking Log '_${log_relation}' was moved";
                    my $count = $payment->search_related( "log_payment_${log_relation}" )->count;
                    cmp_ok( $count, '==', 0, "no Logs for 'log_payment_${log_relation}' are on the Payment record" );
                    $count = $replaced_payment->search_related( "log_replaced_payment_${log_relation}" )->count;
                    cmp_ok( $count, '==', 1, "a Log for 'log_replaced_payment_${log_relation}' has been created for the Replaced Payment" );
                }
            }

            # if required get another Pre-Auth
            if ( $setup->{repeat} ) {
                note "Making a subsequent Pre-Auth request";

                $orig_payment = _payment_as_hash( $payment );

                $self->_make_full_cycle_request( $order );

                isnt( $payment->discard_changes->psp_ref, $orig_payment->{psp_ref},
                                "PSP Ref. has been Updated on 'orders.payment' record" );
                isnt( $payment->preauth_ref, $orig_payment->{preauth_ref},
                                "Pre-Auth Ref. has been Updated on 'orders.payment' record" );

                cmp_ok( $order->discard_changes->replaced_payments->count, '==', 2,
                                "Two 'orders.replaced_payment' records have been created" );
                %replaced_payment = $order->replaced_payments->search( {}, { order_by => 'id DESC' } )->first->get_columns;
                cmp_deeply( \%replaced_payment, superhashof( $orig_payment ),
                                "and New Replaced Payment matches the recently Updated Payment" );
            }
        };
    }
}

=head2 test_shipment_on_hold_for_third_party_psp_is_released

This makes sure that if a Shipment is on Hold for Third Party PSP
Reasons, such as 'Pending' or 'Rejected' that when creating a new
Pre-Auth takes the Shipment off Hold.

=cut

sub test_shipment_on_hold_for_third_party_psp_is_released : Tests {
    my $self = shift;

    my $order    = $self->{order};
    my $shipment = $self->{shipment};

    note "Try when there is NO Payment, make sure getting a new Pre-Authe doesn't DIE";
    $order->payments->delete;

    $self->_make_full_cycle_request( $order );


    note "Now try with a Payment & Shipment on Hold";

    # create a Third Party Payment for the Order
    $self->{create_payment_args}{payment_method} = $self->{third_party_payment_method};
    my $payment = Test::XTracker::Data->create_payment_for_order(
        $order,
        $self->{create_payment_args},
    );

    $shipment->put_on_hold( {
        operator_id => $APPLICATION_OPERATOR_ID,
        status_id   => $SHIPMENT_STATUS__HOLD,
        norelease   => 1,
        reason      => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
        comment     => '',
    } );
    cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__HOLD,
                    "Sanity Check: Shipment is now on Hold" );

    $self->_make_full_cycle_request( $order );

    cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                    "After creating a new Pre-Auth Shipment is NO longer on Hold" );
    my $shipment_status_log = $shipment->shipment_status_logs->search( {}, { order_by => 'id DESC' } )->first;
    cmp_ok( $shipment_status_log->operator_id, '==', $self->{operator}->id,
                    "Shipment Status Log is for the expected Operator: " . $self->{operator}->name );
}

#---------------------------------------------------------------------------

# make a request to the Service
sub _make_request {
    my ($self,  $parameters ) = @_;

    my $handler          = $self->_new_mock_handler;
    $handler->{param_of} = $parameters;

    lives_ok {
        my $auth_payment_obj = XT::Service::Order::AuthorisePayment->new( {
            schema  => $self->schema,
            handler => $handler,
        } );
        $auth_payment_obj->process;
    } "Call to 'XT::Service::Order::AuthorisePayment' lives!";

    return $handler->{data};

}

sub _make_initial_request {
    my ($self,  $order ) = @_;

    return $self->_make_request( {
        orders_id => $order->id,
    } );

}

sub _make_redirect_request {
    my ($self,  $order, $payment_session_id ) = @_;

    return $self->_make_request( {
        orders_id           => $order->id,
        payment_session_id  => $payment_session_id,
        is_redirect_url     => 1,
    } );

}

sub _make_full_cycle_request {
    my ($self,  $order ) = @_;

    # Make the initial request (which should make a request for a new payment
    # session).
    my $data = $self->_make_initial_request( $order );

    isa_ok( $data->{payment_form}->{header}, 'CODE',
        'Form header helper method' );

    lives_ok( sub { $data->{payment_form}->{header}->( 'test_form' ) },
        'Form header helper method lives ok' );

    ok( exists $data->{payment_forms}->{test_form}->{session_id},
        'The session_id created by the previous call to the header helper method, is present' );

    $self->_make_redirect_request(
        $order,
        $data->{payment_forms}->{test_form}->{session_id} );

}

sub _new_mock_handler {
    my $self = shift;

    return Test::XTracker::Mock::Handler->new( {
        operator_id => $self->{operator}->id,
        data     => {
            uri => '/Test/URI',
        },
        param_of => {},
    } );

}

sub _payment_as_hash {
    my ( $payment ) = @_;

    $payment->discard_changes;
    return {
        fulfilled           => $payment->fulfilled,
        orders_id           => $payment->orders_id,
        payment_method_id   => $payment->payment_method_id,
        preauth_ref         => $payment->preauth_ref,
        psp_ref             => $payment->psp_ref,
        settle_ref          => $payment->settle_ref,
        valid               => $payment->valid,
    };

}

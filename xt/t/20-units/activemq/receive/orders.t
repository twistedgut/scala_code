#!/usr/bin/env perl
use NAP::policy 'tt', 'test';
use base 'NAP::Test::Class';

=head1 NAME

orders.t - Messages sent to the 'orders' Topic

=head1 DESCRIPTION

This tests the different messages that are sent to the 'orders' Topic.

=cut

use Test::XTracker::RunCondition    export => [ qw( $distribution_centre ) ];
use Test::XT::Data;

use Test::XTracker::MessageQueue;
use Test::XTracker::Mock::PSP;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
    :shipment_status
    :shipment_hold_reason
    :orders_payment_method_class
);

use DateTime;


sub startup : Test( startup => no_plan ) {
    my $self    = shift;
    $self->SUPER::startup();

    $self->{data} = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Order',
        ],
    );

    my ( $mq, $app ) = Test::XTracker::MessageQueue->new_with_app({
        config_file=> $XTracker::Config::Local::PSP_MESSAGING_CONFIG_FILE_PATH,
    });
    $self->{mq}     = $mq;
    $self->{app}    = $app;

    $self->{third_party_payment} = $self->rs('Orders::PaymentMethod')->search( {
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
    } )->first,

    my @dcs = $self->rs('Public::DistribCentre')->all;
    ( $self->{this_dc} )    = grep { $_->name eq $distribution_centre } @dcs;
    ( $self->{other_dc} )   = grep { $_->name ne $distribution_centre } @dcs;

}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin;

    my @channels      = Test::XTracker::Data->get_web_channels->all;
    my $channel       = $channels[0];
    my $other_channel = $channels[1];

    my $order_details =$self->{data}->new_order(
        channel => $channel,
    );

    $self->{order_details} = $order_details;
    $self->{order}         = $order_details->{order_object};
    $self->{shipment}      = $order_details->{shipment_object};
    $self->{channel}       = $channel;
    $self->{other_channel} = $other_channel;
}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback;
}

sub shut_down : Test( shutdown => no_plan ) {
    my $self    = shift;
    $self->SUPER::shutdown();
}


=head1 METHODS

=head2 test_PaymentStatusUpdate

Tests the 'PaymentStatusUpdate' method which is used when a Third Party
PSP (PayPal) updates the Status of the Order's Payment to either Accepted
or Rejected. Checks the Shipment gets taken off Hold or put on Hold for
depending on the Third Party Status.

=cut

sub test_PaymentStatusUpdate : Tests {
    my $self    = shift;

    my %tests = (
        "Third Party Accepts the Payment" => {
            setup => {
                third_party_status  => 'ACCEPTED',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__PROCESSING,
            },
        },
        "Third Party Rejects the Payment" => {
            setup => {
                third_party_status  => 'REJECTED',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
            },
        },
        "Third Party Accepts the Payment but Shipment is On Hold for another Reason" => {
            setup => {
                hold_reason         => $SHIPMENT_HOLD_REASON__OTHER,
                third_party_status  => 'ACCEPTED',
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__OTHER,
            },
        },
        "Message for an Order Number that exists but has the wrong Channel in the Payload" => {
            setup => {
                third_party_status => 'ACCEPTED',
                channel            => $self->{other_channel},
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            },
        },
        "Message for an Order Number that exists but is for the wrong Instance (DC) in the Payload" => {
            setup => {
                third_party_status => 'ACCEPTED',
                dc_to_use          => $self->{other_dc},
            },
            expect => {
                shipment_status => $SHIPMENT_STATUS__HOLD,
                hold_reason     => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            },
        },
        "Message for an Order that doesn't exist - Example: Not Yet Imported" => {
            setup => {
                order_number       => 'ORDER-123456',
                third_party_status => 'ACCEPTED',
            },
            expect => {
                just_test_request_is_success => 1,
            },
        },
    );

    # don't do the following tests if there is only Channel for the DC
    if ( !$self->{other_channel} ) {
        delete $tests{"Message for an Order Number that exists but has the wrong Channel in the Payload"};
    }

    # get the Queue name out of the Config
    my $queue    = Test::XTracker::Config
                        ->psp_messaging_config->{'Consumer::Orders::PaymentStatusUpdate'}
                            ->{routes_map}{destination};
    like( $queue, qr{/topic/orders},
                    "Queue name is as expected: '${queue}'" );

    my $order    = $self->{order};
    my $shipment = $self->{shipment};

    # get rid an existing Payment record and then
    # create a new one for a Third Party Payment
    $order->discard_changes->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    delete $payment_args->{settle_ref};
    $payment_args->{payment_method} = $self->{third_party_payment};
    Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    TEST:
    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        $shipment->discard_changes->shipment_holds->delete;
        $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
        $shipment->put_on_hold( {
            reason      => $setup->{hold_reason} //
                                $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
            status_id   => $SHIPMENT_STATUS__HOLD,
            norelease   => 1,
            operator_id => $APPLICATION_OPERATOR_ID,
        } );
        # need to call 'discard_changes' again because the 'put_on_hold' method ultimately uses a $dbh connection
        cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__HOLD,
                        "sanity check, shipment is on hold" );

        $self->{mq}->clear_destination( $queue );
        Test::XTracker::Mock::PSP->set_payment_method(
            $self->{third_party_payment}->string_from_psp,
        );
        Test::XTracker::Mock::PSP->set_third_party_status(
            $setup->{third_party_status},
        );

        my $payload = $self->_make_up_PaymentStatusUpdate_payload( {
            order_number    => $setup->{order_number} // $order->order_nr,
            channel         => $setup->{channel}      // $order->channel,
            dc_to_use       => $setup->{dc_to_use}    // $self->{this_dc},
            preauth_ref     => $payment_args->{preauth_ref},
        } );

        my $result = $self->{mq}->request(
            $self->{app},
            $queue,
            $payload,
            { type => 'PaymentStatusUpdate' },
        );
        ok( $result->is_success, "'PaymentStatusUpdate' request processed" )
                or explain $result->content;

        next TEST       if ( $expect->{just_test_request_is_success} );

        $shipment->discard_changes;

        cmp_ok( $shipment->shipment_status_id, '==', $expect->{shipment_status},
                            "Shipment Status is as expected" );

        if ( $expect->{hold_reason} ) {
            cmp_ok( $shipment->shipment_holds->count, '==', 1,
                            "The Shipment has ONE 'shipment_hold' record" );
            my $hold = $shipment->shipment_holds->first;
            cmp_ok( $hold->shipment_hold_reason_id, '==', $expect->{hold_reason},
                            "and it is for the expeted Reason" );
        }
        else {
            cmp_ok( $shipment->shipment_holds->count, '==', 0,
                            "The Shipment has NO 'shipment_hold' records" );
        }
    }

    $self->{mq}->clear_destination( $queue );
}

#-----------------------------------------------------------------------------

# helper to make the Payload for the
# messages processed by 'PaymentStatusUpdate'
sub _make_up_PaymentStatusUpdate_payload {
    my ( $self, $args ) = @_;

    # just get the channel name part & the instance of the DC
    my ( $channel_name ) = split( /-/, $args->{channel}->web_queue_name_part );
    my $channel_inst     = lc( $args->{dc_to_use}->alias );

    my $timestamp = DateTime->now( time_zone => 'UTC' )
                                ->iso8601();

    return {
        order_number => $args->{order_number},
        channel      => "${channel_name}-${channel_inst}",
        timestamp    => $timestamp,
        preauth_ref  => $args->{preauth_ref},
    };
}

Test::Class->runtests;

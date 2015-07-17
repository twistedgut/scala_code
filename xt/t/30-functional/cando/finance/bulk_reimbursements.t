#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

bulk_reimbursements.t - Tests Finance / Reimbursements Page

=head1 DESCRIPTION

Verifies that reimbursements submitted are directed to the correct
message queue and that the page displays the correct error messages
when invalid submissions are made.

#TAGS activemq finance partunit cando

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB         qw ( :authorisation_level :channel );
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw/ config_var /;

my $schema  = Test::XTracker::Data->get_schema;

isa_ok( $schema, "XTracker::Schema" );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::Finance',
    ],
);

isa_ok( $framework, 'Test::XT::Flow' );

my $amq = Test::XTracker::MessageQueue->new;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );

my $queue = config_var('Producer::Order::Reimbursement', 'destination');

ok( defined $queue && $queue ne '', 'Queue name has been defined' );

my $maximum_credit_value = config_var( 'Reimbursements', 'maximum_credit_value' );

ok( defined $maximum_credit_value && $maximum_credit_value > 0, 'Maximum credit value has been defined' );

# get any Renumeration Reason to use for the Tests
my $invoice_reason = $schema->resultset('Public::RenumerationReason')->get_compensation_reasons->first;

# ===== Create Orders =====

my $order;

foreach my $channel ( qw( mrp nap ) ) {

    foreach my $index ( 0 .. 1 ) {

        my $new_order = $framework->flow_db__fulfilment__create_order_selected(
            channel  => Test::XTracker::Data->channel_for_business( name => $channel ),
        );

        isa_ok( $new_order->{order_object}, 'XTracker::Schema::Result::Public::Orders', "order for $channel($index)" );

        $order->{$channel}->[$index] = $new_order->{order_object}->order_nr;

    }

}

# ===== Test Log In =====

note "Accessging Finance/Reimbursements page with no roles";

# assign NO Roles to the Operator
$framework->login_with_roles();


$framework->catch_error(
    qr/don't have permission to/i,
    q{Can't access the /Finance/Reimbursements page},
    flow_mech__finance__reimbursements => ()
);


note "Accessing Finance/Reimbursements page with role";

$framework->login_with_roles( {
    paths => [
        '/Finance/Reimbursements',
        '/Finance/Reimbursements/BulkConfirm',
        '/Finance/Reimbursements/BulkDone',
    ]
});

$framework->{mech}->no_feedback_error_ok;


# ===== Tests =====
my $channel_id = Test::XTracker::Data->channel_for_business(name=>'nap')->id;

# Test the Form Contents

    # Disable one of the reasons and remember the state.
    my $old_status = $invoice_reason->enabled;
    $invoice_reason->update({ enabled => 0 });

    # Go to the Reimbursement page.
    $framework->flow_mech__finance__reimbursements;

    # Get all channels that are not fulfilment only.
    my @expected_channels = map { $_->business->name }
        $schema->resultset('Public::Channel')
            ->fulfilment_only(0)
            ->all;

    # Get the channels in the drop down.
    my @got_channels = map { $_->{name} }
        @{ $framework->mech->as_data->{channels} };

    # Check the list of channels is correct.
    cmp_deeply( \@got_channels, \@expected_channels,
        'The list of channels is correct' );

    # Get all the reasons from the drop down.
    my @reasons = @{ $framework->mech->as_data->{invoice_reasons} };

    # Count how many times the disabled reason appears in the list using both
    # the name and the id.
    my $disabled_name_count = grep { $_->{name}  eq $invoice_reason->reason } @reasons;
    my $disabled_id_count   = grep { $_->{value} eq $invoice_reason->id     } @reasons;

    # Check the disabled reason does not appear at all.
    cmp_ok( $disabled_name_count, '==', 0, 'Reason NOT found in the Drop Down (by Name)' );
    cmp_ok( $disabled_id_count, '==', 0, 'Reason NOT found in the Drop Down (by ID)' );

    # Restore the original state for the reason.
    $invoice_reason->update({ enabled => $old_status });

# Success

    # With Email

    $amq->clear_destination($queue);

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            send_email      => 1,
            channel         => $channel_id,
            credit_amount   => 25,
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } )
        ->flow_mech__finance__reimbursements__bulk_confirm_submit( {
            email_subject   => 'Test Subject',
            email_message   => 'Test Message',
        } );

    $framework->mech->no_feedback_error_ok( 'success with email' );
    my $bulk_reimbursement_id = $framework->mech->as_data->{'bulk_reimbursement_id'};
    my $bulk_rec              = $schema->resultset('Public::BulkReimbursement')->find( $bulk_reimbursement_id );
    is( $bulk_rec->reason, 'Test Notes', "Notes found on 'bulk_reimbursement' record" );
    cmp_ok( $bulk_rec->renumeration_reason_id, '==', $invoice_reason->id, "Invoice Reason found on 'bulk_reimbursement' record" );

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'bulk',
        }),
        assert_body => superhashof({
            'reimbursement_id' => $bulk_reimbursement_id,
        }),
    }, 'Message contains the correct data and is going in the correct queue');

    # Without Email

    $amq->clear_destination($queue);

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            send_email      => 0,
            channel         => $channel_id,
            credit_amount   => 25,
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } )
        ->flow_mech__finance__reimbursements__bulk_confirm_submit;

    $framework->mech->no_feedback_error_ok( 'success without email' );

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'bulk',
        }),
        assert_body => superhashof({
            'reimbursement_id' => $framework->mech->as_data->{'bulk_reimbursement_id'},
        }),
    }, 'Message contains the correct data and is going in the correct queue');

# Failure

    $framework->errors_are_fatal(0);

    my %message = (
        'credit_amount'     => qr/Please enter a valid credit amount greater than zero/i,
        'notes'             => qr/Please enter valid notes of no more than 250 characters/i,
        'orders_empty'      => qr/Please enter a valid list of orders/i,
        'orders_multiple'   => qr/Please enter a list of orders from only the selected channel/i,
        'invoice_reason'    => qr/Please select a reason/i,
    );

    # credit_amount

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => '',
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{credit_amount}, 'credit_amount empty' );

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => '£25.00',
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{credit_amount}, 'credit_amount pound sign' );

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => 'Twenty-Five',
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{credit_amount}, 'credit_amount string' );

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => -25,
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{credit_amount}, 'credit_amount negative' );

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => $maximum_credit_value + 1,
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{credit_amount}, 'credit_amount too large' );

    # reason

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => $maximum_credit_value,
            invoice_reason_id => '',
            notes           => 'Test Notes',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{invoice_reason}, 'no reason selected' );

    # notes

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => $maximum_credit_value,
            invoice_reason_id => $invoice_reason->id,
            notes           => '',
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{notes}, 'notes empty' );

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => 25,
            invoice_reason_id => $invoice_reason->id,
            notes           => '1234567890' x 26,
            orders          => "$order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{notes}, 'notes greater than 250 chars' );

    # orders

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => 25,
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => '',
        } );

    like( $framework->mech->app_error_message, $message{orders_empty}, 'orders empty' );

    $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => 25,
            invoice_reason_id => $invoice_reason->id,
            notes           => 'Test Notes',
            orders          => "$order->{mrp}->[0] $order->{mrp}->[1] $order->{nap}->[0] $order->{nap}->[1]",
        } );

    like( $framework->mech->app_error_message, $message{orders_multiple}, 'orders multiple channels' );

    # all empty

   $framework
        ->flow_mech__finance__reimbursements
        ->flow_mech__finance__reimbursements_submit( {
            channel         => $channel_id,
            credit_amount   => '',
            invoice_reason_id => '',
            notes           => '',
            orders          => '',
        } );

    ok(
        $framework->mech->app_error_message =~ $message{credit_amount} &&
        $framework->mech->app_error_message =~ $message{invoice_reason} &&
        $framework->mech->app_error_message =~ $message{notes} &&
        $framework->mech->app_error_message =~ $message{orders_empty},
        'all empty'
    );

# ===== DONE =====

done_testing();


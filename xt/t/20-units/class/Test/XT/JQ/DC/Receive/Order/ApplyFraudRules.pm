package Test::XT::JQ::DC::Receive::Order::ApplyFraudRules;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::JQ::DC::Receive::Order::ApplyFraudRules

=head1 SYNOPSIS

This will test the Job Queue Worker:
    * XT::JQ::DC::Receive::Order::ApplyFraudRules

=head1 TESTS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;

use Test::XT::DC::JQ;
use XT::JQ::DC;

use XTracker::Constants::FromDB         qw( :order_status :fraud_rule_outcome_status );


# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{jq}     = Test::XT::DC::JQ->new;

    # worker that will be tested
    $self->{jq_worker} = 'Receive::Order::ApplyFraudRules';
}

# to be done BEFORE each test runs
sub setup : Test( setup => 3 ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{order}  = Test::XTracker::Data::FraudRule->create_order;
    $self->{jc_order} = Test::XTracker::Data::FraudRule->create_order (
        Test::XTracker::Data->channel_for_business(name=>'jc')
    );
    $self->{channel}= $self->{order}->channel;

    $self->jq->clear_ok;        # clear the job queue
}

=head2 test_can_do_worker

Tests that the Job Queue Worker 'XT::JQ::DC::Receive::Order::ApplyFraudRules'
is configured properly.

=cut

sub test_can_do_worker : Tests {
    my $self    = shift;

    $self->jq->can_do_ok(
        'XT::JQ::DC::Receive::Order::ApplyFraudRules',
        "Job Queue Worker is configured"
    );
}

=head2 test_payload

Test Valid/Invalid Payloads.

=cut

sub test_payload : Tests {
    my $self    = shift;


    #update jc order number
    $self->{jc_order}->update({
        order_nr => 'testing' . $self->{jc_order}->id,
    });

    my %tests   = (
        "Valid Payload" => {
            payload => {
                order_number    => $self->{order}->order_nr,
                channel_id      => $self->{order}->channel_id,
                mode            => 'parallel',
            },
            expected => 1,
        },
        "Invalid Payload, run in 'live' mode" => {
            payload => {
                order_number    => $self->{order}->order_nr,
                channel_id      => $self->{order}->channel_id,
                mode            => 'live',
            },
            expected => 0,
        },
        "Invalid Payload, run in 'test' mode" => {
            payload => {
                order_number    => $self->{order}->order_nr,
                channel_id      => $self->{order}->channel_id,
                mode            => 'test',
            },
            expected => 0,
        },
        "Invalid Payload, a nonsense mode" => {
            payload => {
                order_number    => $self->{order}->order_nr,
                channel_id      => $self->{order}->channel_id,
                mode            => 'nonsense',
            },
            expected => 0,
        },
        "Invalid Payload, NO 'order_number'" => {
            payload => {
                channel_id  => $self->{order}->channel_id,
                mode        => 'parallel',
            },
            expected => 0,
        },
        "Invalid Payload, NO 'channel_id'" => {
            payload => {
                order_number    => $self->{order}->order_nr,
                mode            => 'parallel',
            },
            expected => 0,
        },
        "Invalid Payload, using 'order_id'" => {
            payload => {
                order_id    => $self->{order}->id,
                channel_id  => $self->{order}->channel_id,
                mode        => 'parallel',
            },
            expected => 0,
        },
        "Valid Payload, using 'alphanumeric order_id'" => {
            payload => {
                order_number    => $self->{jc_order}->order_nr,
                channel_id      => $self->{order}->channel_id,
                mode            => 'parallel',
            },
            expected => 1,
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $job = $self->new_job( $test->{payload} );

        if ( $test->{expected} ) {
            lives_ok {
                $job->send_job;
            } "Payload IS Valid";
        }
        else {
            throws_ok {
                $job->send_job;
            } qr/payload.* does not pass the type constraint/i,
            "Payload IS NOT Valid";
        }
    }
}

=head2 test_process_job

Test that the Job does what it's supposed to.

=cut

sub test_process_job : Tests {
    my $self    = shift;

    # don't care which of these Statuses end up being on the
    # Order Outcome record but it can only be one of these
    my @expected_outcome_status = (
        $FRAUD_RULE_OUTCOME_STATUS__PARALLEL_EXPECTED_OUTCOME,
        $FRAUD_RULE_OUTCOME_STATUS__PARALLEL_UNEXPECTED_OUTCOME,
    );

    my $order   = $self->{order};

    # it's the same for all tests
    my $job_payload = {
        order_number    => $order->order_nr,
        channel_id      => $order->channel_id,
        mode            => 'parallel',
    };

    my $statuses    = Test::XTracker::Data->get_allowed_notallowed_statuses(
        'Public::OrderStatus',
        {
            allow   => [
                $ORDER_STATUS__ACCEPTED,
                $ORDER_STATUS__CREDIT_HOLD,
            ],
        },
    );

    note "Test Rules WON'T be Applied if the Order Status ISN'T Correct";
    foreach my $status ( @{ $statuses->{not_allowed} } ) {
        note "using Status: '" . $status->status . "'";

        $order->discard_changes;
        $order->update({ order_status_id => $status->id });
        $self->process_job( $job_payload );

        $order->discard_changes;

        ok( !defined($order->orders_rule_outcome), "No 'orders_rule_outcome' record created" );
    }

    note "Test Rules WILL be Applied if the Order Status IS Correct";
    foreach my $status ( @{ $statuses->{allowed} } ) {
        note "using Status: '" . $status->status . "'";

        $order->discard_changes->update( { order_status_id => $status->id } );
        $order->orders_rule_outcome->delete         if ( $order->orders_rule_outcome );
        $self->process_job( $job_payload );

        my $outcome = $order->discard_changes->orders_rule_outcome;
        isa_ok( $outcome, 'XTracker::Schema::Result::Fraud::OrdersRuleOutcome', "Order has an Outcome record" );
        my $outcome_status_id   = $outcome->rule_outcome_status_id;
        cmp_ok(
            scalar( grep { $outcome_status_id == $_ } @expected_outcome_status ),
            '==',
            1,
            "and the Outcome Status is only One of the Parallel Statuses: '" . $outcome->rule_outcome_status->status . "'"
        );

        note "run the Job again now the Order has an Outcome record";
        $self->process_job( $job_payload );
    }
}

#----------------------------------------------------------------------------------

sub jq {
    my $self    = shift;
    return $self->{jq};
}

sub new_job {
    my ( $self, $payload )  = @_;

    return XT::JQ::DC->new( {
        funcname    => $self->{jq_worker},
        payload     => $payload,
    } );
}

sub process_job {
    my ( $self, $payload )  = @_;

    my $job = $self->new_job( $payload );
    my $jh  = $job->send_job;   # get a Job Handle
    $self->jq->process_job_ok( $jh, "Job gets Processed" );

    return;
}


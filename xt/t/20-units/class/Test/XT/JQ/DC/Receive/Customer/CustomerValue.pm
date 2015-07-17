package Test::XT::JQ::DC::Receive::Customer::CustomerValue;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::JQ::DC::Receive::Customer::CustomerValue

=head1 SYNOPSIS

This will test the Job Queue Worker:
    * XT::JQ::DC::Receive::Customer::CustomerValue

=head1 TESTS

=cut

use Test::XTracker::Data;

use Test::XT::DC::JQ;
use XT::JQ::DC;


# to be done first before ALL the tests start
sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{jq}     = Test::XT::DC::JQ->new;

    # worker that will be tested
    $self->{jq_worker} = 'Receive::Customer::CustomerValue';
}

# to be done BEFORE each test runs
sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
        ],
    );

    $self->{customer}  = $data->customer;
    $self->{channel}   = $data->channel;

    $self->jq->clear_ok;        # clear the job queue
}

=head2 test_can_do_worker

Tests that the Job Queue Worker 'XT::JQ::DC::Receive::Customer::CustomerValue'
is configured properly.

=cut

sub test_can_do_worker : Tests {
    my $self    = shift;

    $self->jq->can_do_ok(
        'XT::JQ::DC::Receive::Customer::CustomerValue',
        "Job Queue Worker is configured"
    );
}

=head2 test_payload

Test Valid/Invalid Payloads.

=cut

sub test_payload : Tests {
    my $self    = shift;

    my %tests   = (
        "Valid Payload" => {
            payload => {
                customer_number    => $self->{customer}->is_customer_number,
                channel_id      => $self->{customer}->channel_id,
            },
            expected => 1,
        },
        "Invalid Payload, NO 'customer_number'" => {
            payload => {
                channel_id  => $self->{customer}->channel_id,
            },
            expected => 0,
        },
        "Invalid Payload, NO 'channel_id'" => {
            payload => {
                customer_number    => $self->{customer}->is_customer_number,
            },
            expected => 0,
        },
        "Invalid Payload, using 'customer_id'" => {
            payload => {
                customer_id    => $self->{customer}->id,
                channel_id  => $self->{customer}->channel_id,
            },
            expected => 0,
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



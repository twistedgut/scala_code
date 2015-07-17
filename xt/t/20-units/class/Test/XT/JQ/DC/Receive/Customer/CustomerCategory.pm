package Test::XT::JQ::DC::Receive::Customer::CustomerCategory;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::JQ::DC::Receive::Customer::CustomerCategory

=head1 SYNOPSIS

    # override send_email method
This will test the Job Queue Worker:
    * XT::JQ::DC::Receive::Customer::CustomerCategory

=head1 TESTS

=cut

use Test::XTracker::Data;

use Test::XT::DC::JQ;
use XT::JQ::DC;
use Test::XTracker::Data::Operator;
use XTracker::Constants::FromDB     qw( :customer_category );
use Test::MockObject;
use Mock::Quick;

# to be done first before ALL the tests start
sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{jq}     = Test::XT::DC::JQ->new;

    # worker that will be tested
    $self->{jq_worker} = 'Receive::Customer::CustomerCategory';

    $self->jq->clear_ok;        # clear the job queue

    # create operator
    $self->{operator} = Test::XTracker::Data::Operator->create_new_operator();

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
        ],
     );

    $self->{customer}           = $data->customer;
    $self->{channel}            = $data->channel;

    # ensure customer category is "None"
    $self->{customer}->update({category_id => $CUSTOMER_CATEGORY__NONE});
}
# to be done AFTER each test runs
sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->jq->clear_ok;
}

=head2 test_can_do_worker

Tests that the Job Queue Worker 'XT::JQ::DC::Receive::Customer::CustomerCategory'
is configured properly.

=cut

sub test_can_do_worker : Tests {
    my $self    = shift;

    $self->jq->can_do_ok(
        'XT::JQ::DC::Receive::Customer::CustomerCategory',
        "Job Queue Worker is configured"
    );
}

=head2 test_payload

Test Valid/Invalid Payloads

=cut

sub test_payload : Tests {
    my $self    = shift;

    my %tests   = (
        "Valid Payload" => {
            payload => {
                customer_category_id    => $self->{customer}->category_id,
                channel_id              => $self->{channel}->id,
                customer_numbers        => [$self->{customer}->is_customer_number],
                operator_id             => $self->{operator}->id,
            },
            expected => 1,
        },
        "Invalid Payload, NO 'customer_category_id'" => {
            payload => {
                channel_id          => $self->{channel}->id,
                customer_numbers    => [$self->{customer}->is_customer_number],
                operator_id         => $self->{operator}->id,
            },
            expected => 0,
        },
        "Invalid Payload, NO 'channel_id'" => {
            payload => {
                customer_category_id    => $self->{customer}->category_id,
                customer_numbers        => [$self->{customer}->is_customer_number],
                operator_id             => $self->{operator}->id,
            },
            expected => 0,
        },
        "Invalid Payload, NO 'customer_numbers'" => {
            payload => {
                customer_category_id    => $self->{customer}->category_id,
                channel_id              => $self->{channel}->id,
                operator_id             => $self->{operator}->id,
            },
            expected => 0,
        },
        "Invalid Payload, NO 'operator_id'" => {
            payload => {
                customer_category_id    => $self->{customer}->category_id,
                channel_id              => $self->{channel}->id,
                customer_numbers        => [$self->{customer}->is_customer_number],
            },
            expected => 0,
        },
        "Invalid Payload, using 'customer_id'" => {
            payload => {
                customer_id         => $self->{customer}->id,
                channel_id          => $self->{channel}->id,
                customer_numbers    => [$self->{customer}->is_customer_number],
                operator_id         => $self->{operator}->id,
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

=head2 test_category_gets_updated

Tests that the customer category gets updated in the XT database

=cut

sub test_category_gets_updated : Tests {
    my $self    = shift;

    note "customer number: ".$self->{customer}->is_customer_number."\n";
    # create payload
    my $payload = {
                    channel_id => $self->{channel}->id,
                    customer_category_id => $CUSTOMER_CATEGORY__EIP,
                    customer_numbers => [$self->{customer}->is_customer_number],
                    operator_id => $self->{operator}->id,
                };

    # override send_email method
    my %email_contents;
    my $email = qtakeover 'XTracker::EmailFunctions' => ();
    $email->override(
        send_email => sub {
            my ( $from, $replyto, $to, $subject, $msg, $type, $attachments, $email_args ) = @_;
            note "---------------------------- IN REDEFINED 'send_email' function ----------------------------";
            %email_contents = (
                to          => $to,
                subject     => $subject,
                from        => $from,
                replyto     => $replyto,
                body        => $msg,
                type        => $type,
                attachments => $attachments,
                email_args  => $email_args,
            );
            return 1;
        }
    );

    # add to jobqueue
    my $job;
    lives_ok { $job = $self->_send_job($payload, 'Receive::Customer::CustomerCategory') }
        "Payload could be sent to the Job Queue Worker";
    isa_ok( $job, "XT::JQ::DC::Receive::Customer::CustomerCategory", "and Job is as Expected" );

    # check database is updated
    cmp_ok($self->{customer}->discard_changes->category_id,"==", $CUSTOMER_CATEGORY__EIP, "Customer Category updated as expected");

    # check email has been sent
    my $channel_name = $self->{channel}->name;
    my $customer_category = $self->schema->resultset('Public::CustomerCategory')->find($CUSTOMER_CATEGORY__EIP)->category;
    my %expected = (
        to      => $self->{operator}->email_address,
        subject => re(qr/Customer Category Updates for ${channel_name}/i),
        body     => re(qr/Your request to update the customer category to ${customer_category} for ${channel_name}/i),
    );
    cmp_deeply(\%email_contents, superhashof(\%expected), "Email sent as expected")
                    or diag "Got: ".p(%email_contents)."\nExpected: ".p(%expected);

    # restore send_email method
    $email->restore( 'send_email' );

    # clear job queue
    $self->jq->clear_ok;
}

# Creates and executes a job
sub _send_job {
    my ($self, $payload, $worker) = @_;

    my $schema = $self->{schema};

    my $fake_job    = _setup_fake_job();
    my $funcname    = 'XT::JQ::DC::' . $worker;
    my $job         = new_ok( $funcname => [ payload => $payload, schema => $schema, dbh => $schema->storage->dbh, ] );
    my $errstr      = $job->check_job_payload($fake_job);
    die $errstr     if $errstr;
    diag "checked payload ok";
    $job->do_the_task( $fake_job );

    return $job;
}

# setup a fake TheShwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );
    return $fake;
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



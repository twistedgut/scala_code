#!/usr/bin/env perl
use NAP::policy "tt", 'test';

=head2 Correspondence Producers

This tests the Consumers for Receiving Responses for Correspondence which should all use base class:
    * Consumer::ControllerBase::Correspondence

Currently Tests:
    * Consumer::Controller::SMSCorrespondence
            See 'http://confluence.net-a-porter.com/display/FLEXISHIP/SMS+Proxy'
            for message spec.


First done for CANDO-576

=cut

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ];
use Test::MockObject;

use XTracker::Config::Local         qw(
                                        config_var
                                    );
use XTracker::Constants::FromDB     qw(
                                        :sms_correspondence_status
                                    );

my ($amq,$consumer_app) = Test::XTracker::MessageQueue->new_with_app;
my $schema = Test::XTracker::Data->get_schema();

# set-up a fake logger and a place to store calls to it's methods
my %fake_logger_calls;
my $fake_logger = _fake_logger();
{
    no warnings 'redefine','once'; ## no critic(ProhibitNoWarnings)
    *XT::DC::Messaging::Consumer::SMSCorrespondence::log = sub {
        return $fake_logger;
    };
}
if (!$ENV{TEST_VERBOSE}) {
    # silence expected errors when not verbose
    XT::DC::Messaging->log(_fake_logger());
}

#---------------- Tests ----------------
_test_receive_sms( $schema, $amq, $consumer_app, 1 );
#---------------------------------------

done_testing;


# tests receiving a response message from the SMS Proxy
sub _test_receive_sms {
    my ( $schema, $amq, $app, $oktodo )   = @_;

    SKIP: {
        skip '_test_receive_sms', 1     if ( !$oktodo );

        note "TESTING: '_test_receive_sms'";

        my $config  = \%XTracker::Config::Local::config;

        my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
        my ( $order )           = Test::XTracker::Data->create_db_order( { pids => $pids, base => { channel_id => $channel->id } } );

        my $subject = Test::XTracker::Data->create_csm_subject( $channel );
        my ( $csm_rec ) = Test::XTracker::Data->assign_csm_methods( $subject, 'SMS' );

            # set-up an Email Address for Failures to go to
        my $failure_email_config    = 'test_email_address';
        my $failure_email_address   = 'test.email@address.com';
        $config->{ 'Email_' . $channel->business->config_section }{ $failure_email_config } = $failure_email_address;
        $csm_rec->update( { notify_on_failure => $failure_email_config } );

        # redefine 'send_email' to capture what gets passed to it
        my $sent_failure_to = '';
        no warnings "redefine";
        *XTracker::Schema::Result::Public::SmsCorrespondence::send_email = sub {
            $sent_failure_to    = $_[2];
        };
        use warnings "redefine";

        my $consumer_config = XT::DC::Messaging->config->{'Consumer::SMSCorrespondence'};
        my $queue   = $consumer_config->{routes_map}{destination};
        $amq->clear_destination( $queue );

        my $data    = {
            '@type'     => 'SMSResponse',
            id          => 'ID-1234',
            result      => 'SENT',
        };

        # check missing keys in $data fails to be consumed
        foreach my $key ( keys %{ $data } ) {
            next if $key eq '@type'; # missing this is fine
            my $clone   = { %{ $data } };
            delete $clone->{ $key };
            my $result  = $amq->request(
                $app,
                $queue,
                _payload( $clone )
            );
            ok( $result->is_error, "Message Fails to be Consumed when Key: '$key' is missing" );
        }

        # clear all logs of previous calls to Fake Loggers methods
        _clear_fake_logger();

        # try with an invalid 'result' value
        $data->{result} = 'INVALID';
        my $result  = $amq->request(
            $app,
            $queue,
            _payload( $data )
        );
        ok( $result->is_error, "Message with Invalid 'result' Fails to be Consumed" );
        _fake_log_call_ok( 'logcroak', qr/Found an Invalid 'result' value: 'INVALID'/, "Consumer 'logcroak' with Expected Message" );

        # try with a 'SENT' message but not a recongnised Id, should still consume
        _clear_fake_logger();
        $data->{result} = 'SENT';
        $result = $amq->request(
            $app,
            $queue,
            _payload( $data )
        );
        ok( $result->is_success, "'SENT' Message with Non Recongnised Id Consumed Correctly" ) or diag $result->status_line;
        _fake_log_call_ok( 'warn', qr/ID: '$data->{id}' not in the expected format/, "Consumer 'warn' with Id not in expected format" );

        # create an 'sms_correspondence' record and use it's Id in the Message
        _clear_fake_logger();
        my $sms_corr_rec    = $csm_rec->create_related( 'sms_correspondences', {
            sms_correspondence_status_id => $SMS_CORRESPONDENCE_STATUS__PENDING,
            mobile_number   => '+447788990011',
            message         => 'Test Message',
        } );
        $sms_corr_rec->link_sms_correspondence__shipments->create( { shipment_id => $order->get_standard_class_shipment->id } );
        $data->{id} = 'CSM-' . $sms_corr_rec->id;
        note "Use a Recognised Id in the Message: $data->{id}";

        # try with a 'FAILED' message
        $data->{result} = 'FAILED';
        $data->{reason} = 'Failure Code';
        $result = $amq->request(
            $app,
            $queue,
            _payload( $data )
        );
        ok( $result->is_success, "'FAILED' Message Consumed Correctly" ) or diag $result->status_line;
        cmp_ok( $sms_corr_rec->discard_changes->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__FAIL,
                "'sms_correspondence' Status is Now 'Fail'" );
        is( $sms_corr_rec->failure_code, $data->{reason}, "'failure_code' also Updated" );
        is( $sent_failure_to, $failure_email_address, "Failure Notification was Sent to the Expected Address: $sent_failure_to" );
        _fake_log_call_ok( 'warn', "Consumer did NOT Log a 'warn'" );
        _fake_log_call_ok( 'info', "Consumer did NOT Log an 'info'" );

        # try with a 'SENT' message
        _clear_fake_logger();
        $sent_failure_to= '';
        $data->{result} = 'SENT';
        $result = $amq->request(
            $app,
            $queue,
            _payload( $data )
        );
        ok( $result->is_success, "'SENT' Message Consumed Correctly" ) or diag $result->status_line;
        cmp_ok( $sms_corr_rec->discard_changes->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__SUCCESS,
                "'sms_correspondence' Status is Now 'Success'" );
        is( $sent_failure_to, '', "No Failure Notification Email was Sent" );
        _fake_log_call_ok( 'warn', "Consumer did NOT Log a 'warn'" );
        _fake_log_call_ok( 'info', "Consumer did NOT Log an 'info'" );

        # Duplicate Successes
        _clear_fake_logger();
        $sent_failure_to= '';
        $result = $amq->request(
            $app,
            $queue,
            _payload( $data )
        );
        ok( $result->is_success, "'SENT' Message Consumed Correctly" ) or diag $result->status_line;
        cmp_ok( $sms_corr_rec->discard_changes->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__SUCCESS,
                "Duplicate Success: 'sms_correspondence' Status is still 'Success'" );
        is( $sent_failure_to, '', "Duplicate Success: No Failure Notification Email was Sent" );
        _fake_log_call_ok( 'warn', "Consumer did NOT Log a 'warn'" );

        # subsequent Failure after a Success
        _clear_fake_logger();
        $sent_failure_to= '';
        $data->{result} = 'FAILED';
        $data->{reason} = 'New Failure Code';
        $result = $amq->request(
            $app,
            $queue,
            _payload( $data )
        );
        ok( $result->is_success, "'FAILED' Message Consumed Correctly" ) or diag $result->status_line;
        cmp_ok( $sms_corr_rec->discard_changes->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__SUCCESS,
                "Failure after Success: 'sms_correspondence' Status is still 'Success'" );
        is( $sms_corr_rec->failure_code, 'Failure Code', "Failure after Success: 'failure_code' still the same" );
        is( $sent_failure_to, '', "Failure after Success: No Failure Notification Email was Sent" );
        _fake_log_call_ok( 'warn', qr/Status for 'sms_correspondence' rec, Id:.*, already 'Success'/,
                           "Consumer 'warn' with status already Success" );

        note "Test with a Recongnised Id, but with no Record to update (should sit here for a while)";
        _clear_fake_logger();
        # change the config settings
        my $attempts    = 6;
        my $retry_wait  = 3;

        my $consumer=XT::DC::Messaging->component('XT::DC::Messaging::Consumer::SMSCorrespondence');
        # bad dakkar, poking inside Moose object internals!
        $consumer->{sms_retry_count}   = $attempts;
        $consumer->{sms_retry_secs}    = $retry_wait;
        # create an 'sms_correspondence' record and use it's Id in the Message
        $sms_corr_rec   = $csm_rec->create_related( 'sms_correspondences', {
            sms_correspondence_status_id => $SMS_CORRESPONDENCE_STATUS__PENDING,
            mobile_number   => '+447788990011',
            message         => 'Test Message',
        } );
        $data   = {
            '@type'     => 'SMSResponse',
            id          => 'CSM-' . $sms_corr_rec->id,
            result      => 'SENT',
        };
        # now delete the 'sms_correspondence' log so it can't be found
        $sms_corr_rec->delete;
        $result = $amq->request(
            $app,
            $queue,
            _payload( $data )
        );
        ok( $result->is_success, "Message Consumed Correctly" ) or diag $result->status_line;
        _fake_log_call_ok( 'warn', qr{With Id: '\d+', Couldn't find .* try attempt: [2-$attempts]/$attempts.*, after a $retry_wait second wait},
                           "Consumer 'warn' with attempt of attempts message" );
        _fake_log_call_ok( 'error', qr/With a Valid Id: '\d+', Couldn't find a 'sms_correspondence' record after $attempts attempts/,
                           "Consumer 'error' with couldn't find record after $attempts attempts" );


    };

    return;
}

#------------------------------------------------------------------------

# generates a payload and converts it to JSON
sub _payload {
    my ( $data )  = @_;

    return $data, {
        type => 'SMSResponse',
    };
}

# clears out the log of method calls to the fake logger
sub _clear_fake_logger {
    $fake_logger->clear();
    %fake_logger_calls  = ();
    return;
}

# returns the last call to the fake logger and returns
# the name of the method and the message logged
sub _fake_log_call_ok {
    my ( $for_method, $expected, $tst_msg ) = @_;

    # populate the %fake_logger_calls hash
    my ( $name, $args );
    while ( ( $name, $args ) = $fake_logger->next_call() ) {
        push @{ $fake_logger_calls{ $name } }, $args->[1];
    }

    # now try and find the message for the specific method
    my $matched = 0;
    my $found   = 0;
    MESSAGE:
    foreach my $msg ( @{ $fake_logger_calls{ $for_method } } ) {
        $found  = $msg;
        # if $expected is a REGEX
        if ( ref( $expected ) && $msg =~ m/$expected/si ) {
            $matched    = 1;
            last MESSAGE;
        }
    }

    if ( $matched ) {
        if ( ref( $expected ) ) {
            # if $expected is a REGEX then assume it wanted to find something
            pass( $tst_msg || "Fake Logger Call Found Expected Message" );
        }
        else {
            # if $expected is just a string then assume it didn't want to find nothing
            fail( $expected || "Fake Logger Call Found a Message when it was Supposed to find Nothing" );
        }
    }
    else {
        if ( ref( $expected ) ) {
            # if $expected is a REGEX then assume it wanted to find something
            fail( $tst_msg || "Fake Logger Call Couldn't Find Anything" );
        }
        elsif ( $found ) {
            # if $expected is just a string then assume it wanted to find nothing
            fail( ( $expected || "Fake Logger Call Found Something it Wasn't Expecting" ) . ': "'.$found.'"' );
        }
        else {
            pass( $expected || "Fake Logger Call Didn't Find Anything" );
        }
    }

    return;
}

# generates a fake logger
sub _fake_logger {
    my $logger  = Test::MockObject->new( { } );
    $logger->set_isa('Log::Log4perl');

    $logger->mock( 'logcroak', sub { die; } );
    $logger->mock( 'warn', sub { return 1; } );
    $logger->mock( 'info', sub { return 1; } );
    $logger->mock( 'debug', sub { return 1; } );
    $logger->mock( 'error', sub { return 1; } );

    return $logger;
}

#!/usr/bin/env perl
use NAP::policy "tt", 'test';

=head2 Correspondence Producers

This tests the Producers use for Sending Correspondence such as SMS.

Currently Tests:
    * Producer::Correspondence::SMS
            See 'http://confluence.net-a-porter.com/display/FLEXISHIP/SMS+Proxy'
            for message spec.


First done for CANDO-576

=cut

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local     qw(
                                    config_var
                                );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', 'sanity check, got schema' );

my $amq     = Test::XTracker::MessageQueue->new();

#---------------- Tests ----------------
_test_sms( $schema, $amq, 1 );
#---------------------------------------

done_testing;


# tests sending SMS messages to the
# SMS Proxy on the Integration Service
sub _test_sms {
    my ( $schema, $amq, $oktodo )   = @_;

    SKIP: {
        skip '_test_sms', 1     if ( !$oktodo );

        note "TESTING: '_test_sms'";

        my $producer    = 'XT::DC::Messaging::Producer::Correspondence::SMS';
        my @channels    = (
                            Test::XTracker::Data->channel_for_nap,
                            Test::XTracker::Data->channel_for_mrp,
                            Test::XTracker::Data->channel_for_out,
                        );

        foreach my $channel ( @channels ) {
            note "Sales Channel: " . $channel->name;

            my $data    = {
                    message_id  => 'ID-1234',
                    channel     => $channel,
                    message     => 'message body',
                    phone       => '+443322114455',
                    from        => 'from here',
                };
            $channel->web_name  =~ m/(?<channel>.*)-(?<instance>.*)/;
            my $web_name    = $+{channel} . '_' . $+{instance};
            $web_name       =~ s/OUTNET/OUT/;

            my $queue   = config_var('Producer::Correspondence::SMS','destination');
            $amq->clear_destination( $queue );

            # check missing required arguments in call to 'send' will fail
            throws_ok { $amq->transform_and_send( $producer ) } qr/Must pass Arguments/i, "'send' fails when no Arguments are passed";
            throws_ok { $amq->transform_and_send( $producer, [ 1 ] ) } qr/Must pass Arguments/i, "'send' fails when Invalid Arguments are passed";

            # check each key and make sure 'send' fails when it's missing
            foreach my $key ( keys %{ $data } ) {
                my $clone   = { %{ $data } };
                # first set the key to have no value
                $clone->{ $key }    = '';
                throws_ok { $amq->transform_and_send( $producer, $clone ) } qr/Missing or Empty '$key' in Arguments/i,
                                                    "'send' fails when Key: '$key' is Empty in Arguments passed";
                # now delete the key from the hash
                delete $clone->{ $key };
                throws_ok { $amq->transform_and_send( $producer, $clone ) } qr/Missing or Empty '$key' in Arguments/i,
                                                    "'send' fails when Key: '$key' is Missing from Arguments passed";
            }

            # check when everything is correct, then it works
            lives_ok { $amq->transform_and_send( $producer, $data ) } "Can Send a Valid Message when the Correct Arguments are passed in";
            $amq->assert_messages( {
                destination => $queue,
                filter_header => superhashof({
                    type => 'SMSMessage',
                }),
                assert_body => superhashof({
                    id              => $data->{message_id},
                    salesChannel    => $web_name,
                    message         => {
                        body        => $data->{message},
                        from        => $data->{from},
                        phoneNumber => $data->{phone},
                    },
                }),
            }, "Message Sent as Expected on Queue '$queue'" );
        }
    };

    return;
}

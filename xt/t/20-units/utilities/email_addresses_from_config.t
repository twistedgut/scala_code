#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 XTracker::Config::Local Test

Tests various functions in the 'XTracker::Config::Local' package that get Email Addresses out of the Config.

currently tests:

    * email_address_for_setting

=cut

use Test::XTracker::Data;
use_ok( 'XTracker::Config::Local', qw(
                                email_address_for_setting
                            ) );
use_ok( 'XTracker::Config::Local', qw(
                                email_address_for_setting
                            ) );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', "sanity check got a Schema" );

#------------- TESTS -------------
_test_email_address_for_setting( $schema, 1 );
#---------------------------------

done_testing;


# tests the 'email_address_for_setting' function
sub _test_email_address_for_setting {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip '_test_email_address_for_setting',1        if ( !$oktodo );

        note "TESTING: _test_email_address_for_setting";

        my $channel         = Test::XTracker::Data->channel_for_nap;
        my $conf_section    = $channel->business->config_section;

        # get a copy of the config
        my $config  = \%XTracker::Config::Local::config;

        # set an Email Address for the Sales Channel and a General Email Address
        my $channel_email_config    = 'channel_alert';
        my $channel_email_address   = 'channel_alert@this.com';
        my $nonchan_email_config    = 'nonchan_alert';
        my $nonchan_email_address   = 'nonchan_alert@this.com';

        $config->{ "Email_${conf_section}" }{ $channel_email_config }   = $channel_email_address;
        $config->{ "Email" }{ $nonchan_email_config }                   = $nonchan_email_address;

        # make a General Email version of the Sales Channel Email
        # Address to make sure that the correct version is returned
        $config->{Email}{ $channel_email_config }   = 'SHOULD.NOT@BE.RETURNED';

        note "Testing 'email_address_for_setting' function";

        note "using Channel Email Address    : $channel_email_config - $channel_email_address";
        note "using Non-Channel Email Address: $nonchan_email_config - $nonchan_email_address";

        my %tests   = (
                "No Setting passed, get an Empty String back, with No Channel Passed" => {
                        setting => undef,
                        expected=> "",
                    },
                "No Setting passed, get an Empty String back, with Channel Passed" => {
                        setting => undef,
                        expected=> "",
                        channel => 1,
                    },
                "Non-Channelised Email Setting, with No Channel Passed" => {
                        setting => $nonchan_email_config,
                        expected=> $nonchan_email_address,
                        channel => 0,
                    },
                "Non-Channelised Email Setting, with Channel Passed" => {
                        setting => $nonchan_email_config,
                        expected=> $nonchan_email_address,
                        channel => 1,
                    },
                "Channelised Email Setting, with Channel Passed" => {
                        setting => $channel_email_config,
                        expected=> $channel_email_address,
                        channel => 1,
                    },
                "Channelised Email Setting, with No Channel Passed" => {
                        setting => $channel_email_config,
                        expected=> 'SHOULD.NOT@BE.RETURNED',    # should get the non-channelised version
                        channel => 0,
                    },
                "Non-Existing Email Setting, with Channel Passed" => {
                        setting => 'sdfsf',
                        expected=> "",
                        channel => 0,       # shouldn't find anything
                    },
            );
        foreach my $label ( keys %tests ) {
            note "Testing: $label";
            my $test    = $tests{ $label };

            if ( $test->{channel} ) {
                is( email_address_for_setting( $test->{setting}, $channel ), $test->{expected},
                                                "With Channel Rec: got the Expected Email Address: '$test->{expected}'" );
                is( email_address_for_setting( $test->{setting}, $conf_section ), $test->{expected},
                                                "With Channel Config Section: got the Expected Email Address: '$test->{expected}'" );
            }
            else {
                is( email_address_for_setting( $test->{setting} ), $test->{expected}, "got the Expected Email Address: '$test->{expected}'" );
            }
        }
    };

    return;
}

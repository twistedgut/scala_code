#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 Online Fraud Hot List

This will test the config for whether a DC should listen to updates from
other DCs to update its 'hotlist_value' table.

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ '$distribution_centre' ];

my %bool_map    = (
    yes => 1,
    no  => 0,
);

my %tests   = (
    DC1 => {
        listen_for_hotlist_update   => {
            value       => 'no',
        },
    },
    DC2 => {
        listen_for_hotlist_update   => {
            value       => 'no',
        },
    },
    DC3 => {
        listen_for_hotlist_update   => {
            value       => 'yes',
        },
    },
);
my $test    = $tests{ $distribution_centre };
if ( !$test ) {
    fail( "No Tests have been set-up for this DC: $distribution_centre" );
    done_testing();
    exit;
}

my $messaging_config = Test::XTracker::Config->messaging_config;

foreach my $setting ( keys %{ $test } ) {
    note "TEST Setting: '${setting}'";
    my $expect  = $test->{ $setting };

    my $value   = $messaging_config->{'Consumer::OnlineFraud'}{$setting};
    is( $value, $expect->{value}, "config value is as expected: " . $expect->{value} );

}

done_testing();

#!/usr/bin/env perl


use NAP::policy "tt",     'test';

=head1

This tests the 'ChannelsForAction' DB System Config section.

=cut

use Test::XTracker::Data;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', "sanity check for Schema" );


# list of Actions and the Config Sections that
# are expected to be in the System Config
my %expected_actions    = (
        'Reservation/Upload'    => [ qw( NAP MRP ) ],
    );

my $config_setting_rs   = $schema->resultset('SystemConfig::ConfigGroupSetting');

foreach my $action ( keys %expected_actions ) {
    my $expected    = $expected_actions{ $action };

    my $setting = $config_setting_rs->config_var( 'ChannelsForAction', $action );
    is_deeply( $setting, $expected, "For Action: '$action', got Expected Channel Config Sections" );
}


done_testing;

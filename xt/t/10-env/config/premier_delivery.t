#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Configs for Premier Delivery

This is a place to test for general configs for the Premier Delivery service.

Currently tests:
    * Which Methods of Alerting a Customer about an Impending Delviery can be used per Sales Channel
    * Whether or not to truncate Addresses in the Routing File

Introduced for CANDO-80

=cut



use Data::Dump qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ qw( $distribution_centre ) ];

use XTracker::Config::Local     qw(
                                    config_var
                                    can_truncate_addresses_for_premier_routing
                                );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $sys_config  = $schema->resultset('SystemConfig::ConfigGroupSetting');

# get a list of channels in a hash
# keyed by their config section
my %channels    = map { $_->business->config_section => $_ } $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->all;


note "TEST Methods of Alerting Customers about Deliveries";

# set-up expected result per channel
my %expected    = (
        'NAP'   => {
                SMS => ( $distribution_centre =~ m/DC[1]/ ? 'On' : 'Off' ),
                Email => 'On',
                send_hold_alert_threshold => ( $distribution_centre =~ m/DC[13]/ ? 3 : 1 ),
            },
        'OUTNET'=> {
                SMS => ( $distribution_centre eq 'DC3' ? 'Off' : 'On' ),
                Email => 'On',
                send_hold_alert_threshold => ( $distribution_centre =~ m/DC[13]/ ? 3 : 1 ),
            },
        'MRP'   => {
                SMS => ( $distribution_centre eq 'DC1' ? 'On' : 'Off' ),
                Email => 'On',
                send_hold_alert_threshold => ( $distribution_centre =~ m/DC[13]/ ? 3 : 1 ),
            },
        'JC'    => {
                SMS => 'Off',
                Email => 'Off',
                send_hold_alert_threshold => ( $distribution_centre =~ m/DC[13]/ ? 3 : 1 ),
            },
    );
my %xlate       = (     # used to translate On & Off to their Boolean equivalents
        On  => 1,
        Off => 0,
    );

while ( my ( $key, $methods )   = each %expected ) {
    my $channel     = $channels{ $key };

    note "Sales Channel: " . $channel->id . " - " . $channel->name;

    # check out the 'send_hold_alert_threshold' system config setting first
    my $expected_val= delete $methods->{send_hold_alert_threshold};
    my $conf_val    = $sys_config->config_var( 'Premier_Delivery', 'send_hold_alert_threshold', $channel->id );
    ok( defined $conf_val, "'send_hold_alert_threshold' value IS defined" );
    cmp_ok( $conf_val, '==', $expected_val, "'send_hold_alert_threshold' value as expected: $expected_val" );
    $conf_val       = $channel->premier_hold_alert_threshold;
    ok( $conf_val, "'premier_hold_alert_threshold' method returns a defined value" );
    cmp_ok( $conf_val, '==', $expected_val, "'premier_hold_alert_threshold' value as expected: $expected_val" );

    while ( my ( $method, $value ) = each %{ $methods } ) {
        # check the value in the System Config tables
        $conf_val   = $sys_config->config_var( 'Premier_Delivery', $method . ' Alert', $channel->id );      # append ' Alert' to Method
        is( lc( $conf_val ), lc( $value ), "System Config Value as expected for '$method': $value" );

        # check the result from the $channel->can_premier_send_alert_by method
        my $boolean = $xlate{ $value };
        cmp_ok( $channel->can_premier_send_alert_by( $method ), '==', $boolean, "'can_premier_send_alert_by' method returns as expected: $boolean" );

        $schema->txn_do( sub {
            # turn off the global setting for the method and check 'can_premier_send_alert_by' returns FALSE
            Test::XTracker::Data->remove_config_group( 'Customer_Communication', $channel );
            Test::XTracker::Data->create_config_group( 'Customer_Communication', { channel => $channel, settings => [ { setting => $method, value => 'Off' } ] } );
            cmp_ok( $channel->can_premier_send_alert_by( $method ), '==', 0,
                                                    "'can_premier_send_alert_by' method returns FALSE when Global Config is 'Off'" );

            # remove the group and check it returns FALSE
            Test::XTracker::Data->remove_config_group( 'Premier_Delivery', $channel );
            cmp_ok( $channel->can_premier_send_alert_by( $method ), '==', 0,
                                                    "'can_premier_send_alert_by' method returns FALSE when there is NO Config Group" );

            # rollback changes
            $schema->txn_rollback();
        } );
    }
}

note "TESTS Config in regards to Truncating Addresses in the Premier Routing file";

%expected = (
    DC1 => 'yes',
    DC2 => 'yes',
    DC3 => 'no',
);
my $dc_expected = $expected{ $distribution_centre };
if ( !$dc_expected ) {
    fail( "No Tests defined for this DC: '${distribution_centre}'" );
}
else {
    my $expect_from_function = ( $dc_expected eq 'yes' ? 1 : 0 );
    my $got = config_var( 'Carrier_Premier', 'truncate_address_lines_in_routing_file' );
    is( $got, $dc_expected,
                "'truncate_address_lines_in_routing_file' setting as expected: '${dc_expected}'" );
    $got    = can_truncate_addresses_for_premier_routing();
    cmp_ok( $got, '==', $expect_from_function,
                "'can_truncate_addresses_for_premier_routing' function returns as expected: '${expect_from_function}'" );
}

done_testing;

#-------------------------------------------------------------------------------

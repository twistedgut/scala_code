#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 CANDO-506: Checks Various Settings to do with OrderImporter

This will test the following settings in the Config file:

* That order_importer_status function returns correct setting

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ qw( $distribution_centre ) ];

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    order_importer_send_fail_email
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    order_importer_send_fail_email
                                ) );

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Sanity Check' );

my %expected_result   = (
    DC1 => {
        'NAP'   => {
            send_error_email => 1,
        },
        'OUTNET'=> {
            send_error_email => 1,
        },
        'MRP'   => {
            send_error_email => 1,
        },
        'JC'    => {
            send_error_email => '0',
            },
     },
    DC2 => {
        'NAP'   => {
            send_error_email => 1,
        },
        'OUTNET'=> {
            send_error_email => 1,
        },
        'MRP'   => {
            send_error_email => 1,
        },
        'JC'    => {
            send_error_email => 0,
        },
    },
    DC3 => {
        'NAP'   => {
            send_error_email => 1,
        },
        'OUTNET'=> {
            send_error_email => 1,
        },
        'MRP'   => {
            send_error_email => 1,
        },
        'JC'    => {
            send_error_email => 0,
        },
    },
);

if ( !exists( $expected_result{ $distribution_centre } ) ) {
    fail( "Can't find any Expected Details for the DC: $distribution_centre" );
}

note "Testing OrderImporter_Channel setting ";

# get the relevent DC's details to expect
my $expected_dc = $expected_result{ $distribution_centre };
# get all Sales Channels
my @channels    = $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->all;

cmp_ok( order_importer_send_fail_email(), '==', 1, "'order_importer_send_fail_email' - When 'undef' passed for Channel then Returns TRUE" );
cmp_ok( order_importer_send_fail_email(""), '==', 1, "'order_importer_send_fail_email' - When 'empty string' passed for Channel then Returns TRUE" );

foreach my $channel ( @channels ) {

    note "************* Sales Channel: ".$channel->name . " - Testing 'order_importer_send_fail_email' function";

    my $conf_section    = $channel->business->config_section;
    my $expected        = $expected_dc->{ $conf_section };

    is( order_importer_send_fail_email( $channel ), $expected->{'send_error_email'}, "Config setting is as Expected from order_importer_send_fail_email method " );

    my $config_result = config_var( 'OrderImporter_'.$conf_section, 'send_error_email');
    $config_result = $config_result ? uc($config_result) : '';
    my $result = $config_result;
    if( $config_result =~ 'YES' ) {
        $result = 1;
    } elsif( $config_result =~ 'NO' ) {
        $result = 0;
    } else {
        $result = '';
    }
    is( $result, $expected->{ 'send_error_email'}, "Correct setting is found in the config using config_var method");

}

done_testing;

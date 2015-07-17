#!/usr/bin/env perl

use NAP::policy "tt", 'test';


use Test::Exception;

use Data::Dump qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ '$distribution_centre' ];
use XTracker::Constants::FromDB     qw(
                                        :branding
                                    );

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    has_cmsservice
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    has_cmsservice
                                ) );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my %expected   = (
        DC1 => {
            'NAP'   => {
                use_service => '1',
            },
            'OUTNET'=> {
                use_service => '0',
            },
            'MRP'   => {
                use_service => '0',
            },
            'JC'    => {
                use_service  => '1',
            },
        },
        DC2 => {
            'NAP'   => {
                use_service => '1',
            },
            'OUTNET'=> {
                use_service => '0',
            },
            'MRP'   => {
                use_service => '0',
            },
            'JC'    => {
                use_service  => '1',
            },
        },
        DC3 => {
            'NAP'   => {
                use_service => '1',
            },
            'OUTNET'=> {
                use_service => '0',
            },
            'MRP'   => {
                use_service => '0',
            },
            'JC'    => {
                use_service  => '0',
            },
        },
    );

if ( !exists( $expected{ $distribution_centre } ) ) {
    fail( "Can't find any Expected Details for the DC: $distribution_centre" );
}

my %got = ();

my @channels    = $schema->resultset('Public::Channel')->search( {}, { order_by => 'me.id' } )->all;

foreach my $channel ( @channels ) {

    my $channel_name = $channel->business->config_section;
    my $section      = "CMSService_".$channel_name;

    #using config section directly
    my $conf_setting    = ( $expected{$distribution_centre}{$channel_name}{use_service} ? 'yes' : 'no' );
    is( config_var( $section, 'use_service'), $conf_setting , "Config setting is correct for ". $section );

    #using has_cmsservice method
    $got{$distribution_centre}{$channel_name}{use_service} =  has_cmsservice($channel_name);

}

is_deeply($got{$distribution_centre},$expected{$distribution_centre}, "Config Function 'has_cmsservice' returns correct data");

done_testing;

#-------------------------------------------------------------------------------

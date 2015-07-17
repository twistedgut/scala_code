#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-489: Checks credit_hold_threshold table for values

This tests that the threshold values are set-up correctly in each DC and for each channel in following table

*credit_hold_threshold

=cut



use Data::Dump qw( pp );
use Data::Dumper;

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ '$distribution_centre' ];


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

# set-up what's expected per DC
my %expected    = (
        DC1 => {
            'NET-A-PORTER.COM'   => {
                'Weekly Order Count' => '5',
                'Daily Order Count'  => '3',
                'Single Order Value' => '2500',
                'Total Order Value'  => '999999',
                'Weekly Order Value' => '999999',
            },
            'theOutnet.com'=> {
                'Weekly Order Count' => '4',
                'Daily Order Count'  => '3',
                'Single Order Value' => '1000',
                'Total Order Value'  => '3000',
                'Weekly Order Value' => '1500',
            },
            'MRPORTER.COM'   => {
               'Weekly Order Count' => '5',
               'Daily Order Count'  => '3',
               'Single Order Value' => '1000',
               'Total Order Value'  => '5000',
               'Weekly Order Value' => '2750',
            },
            'JIMMYCHOO.COM'    => {
               'Weekly Order Count' => '5',
               'Daily Order Count'  =>'3',
               'Single Order Value' => '1750',
               'Total Order Value'  => '5000',
               'Weekly Order Value' => '2750',
            },
        },
        DC2 => {
            'NET-A-PORTER.COM'   => {
                'Weekly Order Count' => '5',
                'Daily Order Count'  => '3',
                'Single Order Value' => '2500',
                'Total Order Value'  => '999999',
                'Weekly Order Value' => '999999',
            },
            'theOutnet.com'=> {
                'Weekly Order Count' => '4',
                'Daily Order Count'  => '3',
                'Single Order Value' => '1000',
                'Total Order Value'  => '3000',
                'Weekly Order Value' => '1500',
            },
            'MRPORTER.COM'   => {
               'Weekly Order Count' => '5',
               'Daily Order Count'  => '3',
               'Single Order Value' => '1000',
               'Total Order Value'  => '5000',
               'Weekly Order Value' => '2000',
            },
            'JIMMYCHOO.COM'    => {
               'Weekly Order Count' => '5',
               'Daily Order Count'  =>'3',
               'Single Order Value' => '1000',
               'Total Order Value'  => '5000',
               'Weekly Order Value' => '2000',
            },
        },
        DC3 => {
            'NET-A-PORTER.COM'   => {
                'Weekly Order Count' => '5',
                'Daily Order Count'  => '3',
                'Single Order Value' => '31000',
                'Total Order Value'  => '12400513',
                'Weekly Order Value' => '12400513',
            },
            # These Channels are currently Disabled in DC3
            # 'theOutnet.com'=> {
            #    'Weekly Order Count' => '4',
            #    'Daily Order Count'  => '3',
            #    'Single Order Value' => '1000',
            #    'Total Order Value'  => '3000',
            #    'Weekly Order Value' => '1500',
            #},
            #'MRPORTER.COM'   => {
            #   'Weekly Order Count' => '5',
            #   'Daily Order Count'  => '3',
            #   'Single Order Value' => '1000',
            #   'Total Order Value'  => '5000',
            #   'Weekly Order Value' => '2000',
            #},
            #'JIMMYCHOO.COM'    => {
            #   'Weekly Order Count' => '5',
            #   'Daily Order Count'  =>'3',
            #   'Single Order Value' => '1000',
            #   'Total Order Value'  => '5000',
            #   'Weekly Order Value' => '2000',
            #},
        },
    );

# check any future DC's have tests set-up for them
if ( !exists( $expected{ $distribution_centre } ) ) {
    fail( "No Tests Set-Up in this Test for: $distribution_centre" );
    done_testing;
    exit;
}

my $got = ();
my @channels = $schema->resultset('Public::Channel')->search( { 'is_enabled'=>1 }, { order_by => 'id' } )->all;

# get order's relevant thresholds
foreach my $channel ( @channels ) {

    note "Got Channel Record for: ".$channel->id." - ".$channel->name ;
    my $thresholds = $channel->credit_hold_thresholds->select_to_hash(
           'Single Order Value',
           'Total Order Value',
           'Weekly Order Value',
           'Weekly Order Count',
           'Daily Order Count',
       );
    $got->{$channel->name} = $thresholds;

}

# compare what has been got with what was expected
is_deeply( $got, $expected{ $distribution_centre }, "Credit threshold Values are as Expected" );

done_testing;

#-------------------------------------------------------------------------------

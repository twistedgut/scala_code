#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Method of Customer Communication Config

This tests the settings in the System Config tables for the 'Customer_Communication' config group for each Sales Channels.


Introduced for CANDO-80

=cut



use Data::Dump qw( pp );

use Test::XTracker::Data;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $sys_config  = $schema->resultset('SystemConfig::ConfigGroupSetting');

# get a list of channels in a hash
# keyed by their config section
my %channels    = map { $_->business->config_section => $_ } $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->all;

# set-up expected result per channel
my %expected    = (
        'NAP'   => {
                SMS => 'On',
                Email => 'On',
            },
        'OUTNET'=> {
                SMS => 'On',
                Email => 'On',
            },
        'MRP'   => {
                SMS => 'On',
                Email => 'On',
            },
        'JC'    => {
                SMS => 'On',
                Email => 'On',
            },
    );
my %xlate       = (     # used to translate On & Off to their Boolean equivalents
        On  => 1,
        Off => 0,
    );

while ( my ( $key, $methods )   = each %expected ) {
    my $channel     = $channels{ $key };

    note "Sales Channel: " . $channel->id . " - " . $channel->name;

    while ( my ( $method, $value ) = each %{ $methods } ) {
        # check the value in the System Config tables
        my $conf_val    = $sys_config->config_var( 'Customer_Communication', $method, $channel->id );
        is( lc( $conf_val ), lc( $value ), "System Config Value as expected for '$method': $value" );

        # check the result from the $channel->can_communicate_to_customer_by method
        my $boolean = $xlate{ $value };
        cmp_ok( $channel->can_communicate_to_customer_by( $method ), '==', $boolean,
                                                    "'can_communicate_to_customer_by' method returns as expected: $boolean" );

        $schema->txn_do( sub {
            # remove the group and check it returns FALSE
            Test::XTracker::Data->remove_config_group( 'Customer_Communication', $channel );
            cmp_ok( $channel->can_communicate_to_customer_by( $method ), '==', 0,
                                                        "'can_communicate_to_customer_by' method returns FALSE when there is NO Config Group" );

            # rollback changes
            $schema->txn_rollback();
        } );
    }
}

done_testing;

#-------------------------------------------------------------------------------

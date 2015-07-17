#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-55: Pending Reservation automated upload

This tests the 'Automatic_Reservation_Upload_Upon_Stock_Updates' config group in the System Config tables and also the 'can_auto_upload_reservations' method on the 'Schema::Result::Public::Channel' class to make sure it returns the correct value for each Sales Channel.

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
        'NAP'       => 'On',
        'OUTNET'    => 'Off',
        'MRP'       => 'On',
        'JC'        => 'Off',
    );
my %xlate       = (     # used to translate On & Off to their Boolean equivalents
        On  => 1,
        Off => 0,
    );

$schema->txn_do( sub {

    while ( my ( $key, $value ) = each %expected ) {
        my $channel     = $channels{ $key };

        note "Sales Channel: " . $channel->id . " - " . $channel->name;

        # check the value in the System Config tables
        my $conf_val    = $sys_config->config_var( 'Automatic_Reservation_Upload_Upon_Stock_Updates', 'state', $channel->id );
        is( lc( $conf_val ), lc( $value ), "System Config Value as expected: $value" );

        # check the result from the $channel->can_auto_upload_reservations method
        my $boolean = $xlate{ $value };
        cmp_ok( $channel->can_auto_upload_reservations, '==', $boolean, "'can_auto_upload_reservations' method returns as expected: $boolean" );

        # remove the group and check it returns FALSE
        Test::XTracker::Data->remove_config_group( 'Automatic_Reservation_Upload_Upon_Stock_Updates', $channel );
        cmp_ok( $channel->can_auto_upload_reservations, '==', 0, "'can_auto_upload_reservations' method returns FALSE when there is NO Config Group" );
    }

    # rollback changes
    $schema->txn_rollback();
} );

done_testing;

#-------------------------------------------------------------------------------

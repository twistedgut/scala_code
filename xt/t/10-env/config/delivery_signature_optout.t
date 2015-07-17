#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-216: Delivery Signature - Opt Out

This will test the setting 'has_delivery_signature_optout' in the 'xtracker_extras_XTDC?.conf' file in the 'DistributionCentre' and the accompanying config function that returns true or false based on its setting.

It also tests the Threshold Order Amounts in the System Config tables for each Sales Channel as to when to put an Order on Credit Hold when the Customer has requested No Delivery Signature.

=cut


use Test::Exception;

use Data::Dump qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ '$distribution_centre' ];

use XTracker::Constants::FromDB     qw( :currency );

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    has_delivery_signature_optout
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    has_delivery_signature_optout
                                ) );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

# get a copy of the conifg
my $config  = \%XTracker::Config::Local::config;

note "Test the 'has_delivery_signature_optout' config option in the 'DistributionCentre' section";

# test the setting in the config file
CASE: {
    if ( $distribution_centre eq "DC1" ) {
        is( config_var( 'DistributionCentre', 'has_delivery_signature_optout' ), 'yes',
                                                "Setting: 'has_delivery_signature_optout' in 'DistributionCentre' Section is NO" );
        last CASE;
    }
    if ( $distribution_centre eq "DC2" ) {
        is( config_var( 'DistributionCentre', 'has_delivery_signature_optout' ), 'yes',
                                                "Setting: 'has_delivery_signature_optout' in 'DistributionCentre' Section is YES" );
        last CASE;
    }
    if ( $distribution_centre eq "DC3" ) {
        is( config_var( 'DistributionCentre', 'has_delivery_signature_optout' ), 'yes',
                                                "Setting: 'has_delivery_signature_optout' in 'DistributionCentre' Section is NO" );
        last CASE;
    }
    fail( "No Test Written for Distribtion Centre: $distribution_centre" );
};

# test the function used to access the setting
$config->{DistributionCentre}{has_delivery_signature_optout} = 'yes';
cmp_ok( has_delivery_signature_optout(), '==', 1, "Config Function 'can_edit_delivery_signature' returns TRUE" );

# change the conifg to being 'no'
$config->{DistributionCentre}{has_delivery_signature_optout} = 'no';
cmp_ok( has_delivery_signature_optout(), '==', 0, "Config Function 'can_edit_delivery_signature' returns FALSE" );

note "Test the Threshold limits for Putting an Order on Credit Hold when No Signature has been Selected";
my @channels    = $schema->resultset('Public::Channel')->search( {}, { order_by => 'me.id' } )->all;

if ( $distribution_centre eq "DC2" ) {
    note "Check DC2 Threshold Levels";
    foreach my $channel ( @channels ) {
        my $threshold   = $schema->resultset('SystemConfig::ConfigGroupSetting')
                                    ->config_var( 'No_Delivery_Signature_Credit_Hold_Threshold', 'USD', $channel->id );
        cmp_ok( $threshold, '==', 2000, "Threshold Level for Channel: ".$channel->name." is 2000" );
        cmp_ok( $channel->is_above_no_delivery_signature_threshold( $threshold, 'USD' ), '==', 1,
                                        "'is_above_no_delivery_signature_threshold' method returns TRUE when passed the Threshold Amount" );
    }
}

note "test the 'is_above_no_delivery_signature_threshold' method";

# test absent parameters are spotted
dies_ok( sub {
        $channels[0]->is_above_no_delivery_signature_threshold();
    }, "'is_above_no_delivery_signature_threshold' dies when no 'Amount' parameter passed in" );
dies_ok( sub {
        $channels[0]->is_above_no_delivery_signature_threshold( 1234 );
    }, "'is_above_no_delivery_signature_threshold' dies when no 'Currency' parameter passed in" );

$schema->txn_do( sub {

    # get a couple of currencies
    my @currencies      = $schema->resultset('Public::Currency')->search(
                                                                    {
                                                                        id => { 'IN' => [ $CURRENCY__GBP, $CURRENCY__USD ] },
                                                                    },
                                                                    {
                                                                        order_by => 'me.currency',
                                                                    } )->all;

    # remove any existing Config Group records
    my $config_group    = $schema->resultset('SystemConfig::ConfigGroup');
    _remove_existing_groups( $config_group, 'No_Delivery_Signature_Credit_Hold_Threshold' );

    # go through each Sales Channel and add 2 currencies
    # and check that the Threshold is being used properly
    foreach my $channel ( @channels ) {
        # create system config settings for Threshold
        my $thresholds  = _create_group_for_channel( $config_group, $channel, \@currencies );

        foreach my $currency ( @currencies ) {
            my $threshold   = $thresholds->{ $currency->id };
            # set-up amounts to use based on the Threshold
            my $below       = $threshold - 101;
            my $equal       = $threshold;
            my $above       = $threshold + 103;

            note "On Channel ". $channel->name. ", using Currency ".$currency->currency;

            # first do it using the 'Public::Currency' object
            cmp_ok( $channel->is_above_no_delivery_signature_threshold( $below, $currency ), '==', 0,
                                            "Using Currency Object: 'Below' Threshold limit method returns FALSE" );
            cmp_ok( $channel->is_above_no_delivery_signature_threshold( $equal, $currency ), '==', 1,
                                            "Using Currency Object: 'Equal' Threshold limit method returns TRUE" );
            cmp_ok( $channel->is_above_no_delivery_signature_threshold( $above, $currency ), '==', 1,
                                            "Using Currency Object: 'Above' Threshold limit method returns TRUE" );

            # now do it again but using the Currency Code
            cmp_ok( $channel->is_above_no_delivery_signature_threshold( $below, $currency->currency ), '==', 0,
                                            "Using Currency Code: 'Below' Threshold limit method returns FALSE" );
            cmp_ok( $channel->is_above_no_delivery_signature_threshold( $equal, $currency->currency ), '==', 1,
                                            "Using Currency Code: 'Equal' Threshold limit method returns TRUE" );
            cmp_ok( $channel->is_above_no_delivery_signature_threshold( $above, $currency->currency ), '==', 1,
                                            "Using Currency Code: 'Above' Threshold limit method returns TRUE" );
        }
    }

    # rollback changes
    $schema->txn_rollback;
} );


done_testing;

#-------------------------------------------------------------------------------

# this will create a 'No_Delivery_Signature_Credit_Hold_Threshold' group and
# populate it with settings for a supplied list of currencies and return the thresholds
sub _create_group_for_channel {
    my ( $config_group, $channel, $currencies ) = @_;

    my %thresholds;

    my $group   = $config_group->create( {
                                    name        => 'No_Delivery_Signature_Credit_Hold_Threshold',
                                    channel_id  => $channel->id,
                                } );

    foreach my $currency ( @{ $currencies } ) {
        $thresholds{ $currency->id } = $currency->id * 1000 + $channel->id;
        $group->create_related( 'config_group_settings', {
                                    setting     => $currency->currency,
                                    value       => $thresholds{ $currency->id },
                                } );
    }

    return \%thresholds;
}

# removes existing 'No_Delivery_Signature_Credit_Hold_Threshold' groups to clear
# the way for tests
sub _remove_existing_groups {
    my ( $config_group, $group_name )   = @_;

    my @groups  = $config_group->search( { name => $group_name } )->all;
    foreach my $group ( @groups ) {
        $group->config_group_settings->delete;
        $group->delete;
    }

    return;
}

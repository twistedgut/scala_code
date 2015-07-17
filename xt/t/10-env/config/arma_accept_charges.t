#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-141: Allow Customer to Accept Exchange Charges when using ARMA

This will test the setting 'arma_accept_exchange_charges' in the 'xtracker_extras_XTDC?.conf' file in the 'DistributionCentre' and the accompanying config function that returns true or false based on its setting.

=cut

use Data::Dump qw( pp );


use Test::XTracker::LoadTestConfig;

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    arma_can_accept_exchange_charges
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    arma_can_accept_exchange_charges
                                ) );

# get a copy of the conifg
my $config  = \%XTracker::Config::Local::config;

# test the setting in the config file
is( config_var( 'DistributionCentre', 'arma_accept_exchange_charges' ), 'yes',
                                            "Setting: 'arma_accept_exchange_charges' in 'DistributionCentre' Section is ON" );

# test the function used to access the setting
cmp_ok( arma_can_accept_exchange_charges(), '==', 1, "Config Function 'arma_can_accept_exchange_charges' returns TRUE" );

# change the conifg to being 'no'
$config->{DistributionCentre}{arma_accept_exchange_charges} = 'no';
cmp_ok( arma_can_accept_exchange_charges(), '==', 0, "Config Function 'arma_can_accept_exchange_charges' returns FALSE" );

done_testing;

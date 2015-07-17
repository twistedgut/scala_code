#!/usr/bin/env perl

use NAP::policy     qw( test );

=head1 NAME

acl_insecure_paths.t

=head1 DESCRIPTION

Tests the 'insecure_paths' part of the 'ACL' Config section.

=cut

use Test::XTracker::LoadTestConfig;

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    acl_insecure_paths
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    acl_insecure_paths
                                ) );


# get the Paths defined direct from the Config and from the Config function
my $acl_config               = config_var( 'ACL', 'insecure_paths' );
my $got_from_config          = $acl_config->{path};
my $got_from_config_function = acl_insecure_paths();

# set what to expect
my $expect_paths = [ qw(
    api
    pricing/prices_for_all_countries
    pricing/reload_cache
    sizing/sizes_for_product
    truckdepartures
    metrics
) ];

cmp_deeply( $got_from_config, $expect_paths,
                    "Got the Expect Paths from 'ACL->insecure_paths->path' Config" );
cmp_deeply( $got_from_config_function, $expect_paths,
                    "and got the Expected paths from calling the 'acl_insecure_paths' function" );


done_testing;


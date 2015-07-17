#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 CANDO-91: Checks the Countries & Sub-Regions Tax & Duty Refunds & Charges

This tests that the Countries & Sub-Regions who can have their Tax & Duties refunded and don't get charged Tax & Duties when making Exchanges are set-up correctly in each DC in the following two tables:

* return_country_refund_charge
* return_sub_region_refund_charge

=cut



use Data::Dump qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ '$distribution_centre' ];


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

# set-up what's expected per DC
my %expected    = (
        DC1 => {
            country => {},      # No Countries for DC1
            sub_region => {
                'EU Member States' => {
                    'Tax'   => {
                        can_refund_for_return   => 1,
                        no_charge_for_exchange  => 1,
                    },
                },
            },
        },
        DC2 => {
            country => {
                'United States' => {
                    'Tax'   => {
                        can_refund_for_return   => 1,
                        no_charge_for_exchange  => 1,
                    },
                },
                'Canada'    => {
                    'Tax'   => {
                        can_refund_for_return   => 1,
                        no_charge_for_exchange  => 1,
                    },
                    'Duty'  => {
                        can_refund_for_return   => 1,
                        no_charge_for_exchange  => 1,
                    },
                },
            },
            sub_region => {},   # No Sub-Regions for DC2
        },
        DC3 => { # DC3 shouldn't have any records in either table
            country => {},
            sub_region  => {},
        },
    );
# check any future DC's have tests set-up for them
if ( !exists( $expected{ $distribution_centre } ) ) {
    fail( "No Tests Set-Up in this Test for: $distribution_centre" );
}

# Get the Country & Sub-Region Refunds & Charges
my @countries   = $schema->resultset('Public::ReturnCountryRefundCharge')->all;
my @sub_regions = $schema->resultset('Public::ReturnSubRegionRefundCharge')->all;

# now build up a HASH that should be the same as what's expected
my $got = {
        country     => {},
        sub_region  => {},
    };
# list of fields to check for on each record
my @fieldlist   = qw(
        can_refund_for_return
        no_charge_for_exchange
    );

# build up countries
foreach my $country ( @countries ) {
    foreach my $field ( @fieldlist ) {
        $got->{country}{ $country->country->country }{ $country->refund_charge_type->type }{ $field }   = $country->$field;
    }
}

# build up sub-regions
foreach my $sub_region ( @sub_regions ) {
    foreach my $field ( @fieldlist ) {
        $got->{sub_region}{ $sub_region->sub_region->sub_region }{ $sub_region->refund_charge_type->type }{ $field }    = $sub_region->$field;
    }
}

# compare what has been got with what was expected
is_deeply( $got, $expected{ $distribution_centre }, "Tax & Duty Refund & Charges Configured as Expected" );

done_testing;

#-------------------------------------------------------------------------------

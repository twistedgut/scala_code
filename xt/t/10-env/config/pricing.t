#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 Product Pricing Rules

General tests for Product Selling Pricing, Covers:

* CANDO-337: Brazil Custom Modifier
             This tests that the Custom Modifier for Brazil has been set for DC2 and not for DC1.

=cut



use Data::Dump qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            dc => [ qw( DC1 DC2 ) ],
                            export => [ qw( $distribution_centre ) ];


my $schema  = Test::XTracker::Data->get_schema;

note "Test Brazil Custom Modifier";
my $country = $schema->resultset('Public::Country')
                        ->search( { country => 'Brazil' } )
                            ->first;
my $tax_rule    = $country->tax_rule_values
                            ->search( { 'tax_rule.rule' => 'Custom Modifier' }, { join => 'tax_rule' } )
                                ->first;
my $tax_rate    = $country->country_tax_rate;

if ( $distribution_centre eq 'DC1' ) {
    ok( !defined $tax_rule, "No 'Custom Modifier' Tax Rule for Brazil in DC1" );
    ok( !defined $tax_rate, "No 'Tax Rate' for Brazil in DC1" );
}
if ( $distribution_centre eq 'DC2' ) {
    cmp_ok( $tax_rule->value, '==', 82, "'Custom Modifier' Tax Rule Value of 82 for Brazil in DC2" );
    cmp_ok( $tax_rate->rate, '==', 0.18, "'Tax Rate' Rate of 0.18 for Brazil in DC2" );
}

done_testing;

#-------------------------------------------------------------------------------

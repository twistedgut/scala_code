#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt",     'test';

=head2 Example Test File for Creating Fraud Rules

This shows people how to create Fraud Rules for their Tests

=cut

use Test::XTracker::Data;

# ONE WAY TO USE THE FUNCTIONALITY
use Test::XT::Data;

my $framework = Test::XT::Data->new_with_traits(
    traits => [
        'Test::XT::Data::Channel',          # required for FraudRule
        'Test::XT::Data::FraudChangeLog',   # required for Creating Live Rules
        'Test::XT::Data::FraudRule',
    ],
);

# the default will be to create a 'Staging' Rule with 5 Conditions
my $rule    = $framework->fraud_rule;

# ANOTHER WAY TO USE THE FUNCTIONALITY
use Test::XTracker::Data::FraudRule;

# this will create a Live Rule with 5 Conditions
$rule   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live' );

# will create 3 Rules
my @rules   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', { how_many => 3 } );

# will create 3 Rules with 2, 3, 4 Conditions in respective order
@rules  = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Staging', [
    { number_of_conditions => 2 },
    { number_of_conditions => 3 },
    { number_of_conditions => 4 },
] );

# will create 3 Rules each with 2 Conditions
my $array_ref   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Staging', {
    hown_many   => 3,
    number_of_conditions => 2,
} );

# will create 2 Rules, with Specific Conditions
@rules  = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
    how_many    => 2,
    conditions_to_use   => [
        {
            method  => 'Order Total Value',
            operator=> '>',
            value   => 234.76,
        },
        {
            # no value specified will get a random value
            method  => 'Shipment Type',
            operator=> '!=',
        },
    ],
} );

ok( 1==1 );

done_testing;


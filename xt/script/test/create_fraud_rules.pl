#!/opt/xt/xt-perl/bin/perl
use NAP::policy "tt";

=head1 NAME

create_fraud_rules.pl- script to create Test 'Live' Fraud Rules

=head1 SYNOPSIS

create_fraud_rules.pl [options]

Will create 100 Rules each with a Random number of Conditions per Rule.

options:

-h, -?, --help
        this page

-r, --rules
        the number of Rules to generate (defualt 100)

            create_fraud_rules.pl -r 58

-c, --max-conditions
        the maxium number of conditions to create per Rule
        (default 7)

            create_fraud_rules.pl -c 5

-f, --always-fail
        will make sure every Rule fails by creating 2 conditions
        per Rule that contradict each other


=head1 DESCRIPTION

This script will create 'Live' Fraud Rules with a random set of Conditions
per Rule.

It will wipe out existing records in the following tables:

    fraud.live_rule
    fraud.live_condition
    fraud.staging_rule
    fraud.staging_condition

and then replace them with the Rules & Conditions it generates.

=cut


use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;
use Test::XT::Data;

use Getopt::Long;
use Pod::Usage;


my %opts;
my $result  = GetOptions( \%opts,
    'rules|r=i',
    'max-conditions|c=i',
    'always-fail|f',
    'help|?|h',
);
pod2usage( -verbose => 2 )          if ( !$result || $opts{help} );

my $schema = Test::XTracker::Data->get_schema;

my $number_of_rules = $opts{rules} // 100;
my $max_conditions  = $opts{'max-conditions'} // 7;
my $always_fail     = $opts{'always-fail'} // 0;

print "Delete Existing Rules\n";
Test::XTracker::Data::FraudRule->delete_fraud_rules;

# the method used in guranteeing each Rule
# will fail, use 'Order Total Value' as this
# is used in 'Applying the Flags' and so will
# already be cached.
my $method_rs           = $schema->resultset('Fraud::Method');
my $method_used_to_fail = $method_rs->find( { description => 'Order Total Value' } );

foreach ( 1..$number_of_rules ) {
    my $data = Test::XT::Data->new_with_traits( {
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::FraudChangeLog',
            'Test::XT::Data::FraudRule',
        ],
    } );
    $data->channel( undef );    # make all Rules for Al Channels
    $data->rule_type( 'Live' );

    # get the Conditions that will be created
    $data->number_of_conditions( int( rand( $max_conditions ) ) + 1 );
    my $conditions  = $data->conditions_to_use;

    if ( $always_fail ) {
        # if asked to add a condition that
        # us guarantaeed to fail
        push @{ $conditions }, {
            method      => $method_used_to_fail,
            operator    => '<',
            value       => 0,
        };
    }
    # create the Rule & Conditions
    my $rule    = $data->fraud_rule;
}

if ( $always_fail ) {
    # make sure the Method used to fail is processed last
    # when Conditions are processed for a Rule
    my $max_cost    = $method_rs->get_column('processing_cost')->max;
    $method_used_to_fail->update( {
        processing_cost => $max_cost + 1,
    } );
}

print "Rules Created: ${number_of_rules}\n";
print "that will ALL Fail\n";

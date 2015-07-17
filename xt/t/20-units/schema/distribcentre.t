#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::Warn;

use_ok( 'Test::XTracker::Data' );
use_ok( 'XTracker::Schema' );
use_ok( 'XTracker::Schema::Result::Public::DistribCentre' );
use_ok( 'XTracker::Schema::ResultSet::Public::DistribCentre' );

my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

my $distrib_centre = $schema->resultset('Public::DistribCentre');
isa_ok( $distrib_centre, 'XTracker::Schema::ResultSet::Public::DistribCentre' );

# These are the specific values we expect to be present.
my %tests = (
    intl => 'DC1',
    am   => 'DC2',
    apac => 'DC3',
);

# ----- Test for specific values -----

while ( my ( $alias, $name ) = each %tests ) {

    my $result = $distrib_centre->find_alias( $alias );
    isa_ok( $result, 'XTracker::Schema::Result::Public::DistribCentre' );

    cmp_ok( $result->name, 'eq', $name, "find_alias returns '$name' for '$alias'" );

}

# ----- Test for a failure when looking up a non-existent alias -----

my $fail;

warning_is(
    sub { $fail = $distrib_centre->find_alias( 'FAIL' ) },
    ref( $distrib_centre ) . '->find_alias: Search failed, zero or more than one records was returned.',
    'find_alias threw warning for non-existent alias'
);

is( $fail, undef, 'find_alias returned undef for non-existent alias' );

# ----- Test for unexpected entries -----

my $unexpected = $distrib_centre->search( {
    alias => {
        'not in' => [ map { uc $_ } keys %tests ],
    },
} );

isa_ok( $unexpected, 'XTracker::Schema::ResultSet::Public::DistribCentre' );

if ( $unexpected->count == 0 ) {

    pass 'No unexpected entries in the distrib_centre table';

} else {

    fail 'No unexpected entries in the distrib_centre table [' . $_->alias . ' -> ' . $_->name . ']'
        foreach $unexpected->all;

}

done_testing;

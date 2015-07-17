#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use_ok('XTracker::BuildConstants');

can_ok(
    'XTracker::BuildConstants',
    qw[
        new
        prepare_constants
        add_constant_group
        spit_out_template
        constants_from_table
        named_constant
    ]
);

my $builder = XTracker::BuildConstants->new;
isa_ok($builder, 'XTracker::BuildConstants');

$builder->prepare_constants();
done_testing;
#$builder->spit_out_template();
#$builder->spit_out_template('/tmp/FromDB.pm');

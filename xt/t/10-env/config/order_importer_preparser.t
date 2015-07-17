#!/usr/bin/env perl

use NAP::policy qw( test );

=head1 NAME

order_importer_preparser.t

=head1 DESCRIPTION

Tests config settings of 'OrderImporterPreParser' section (CANDO-8584)

=cut

use Test::XTracker::Data;

my $schema  = Test::XTracker::Data->get_schema;

isa_ok( $schema, "XTracker::Schema" );
use_ok( 'XTracker::Config::Local', qw(
    config_var
    get_names_for_orderimporter_preparser
));

can_ok( 'XTracker::Config::Local', qw(
    config_var
    get_names_for_orderimporter_preparser
));

#get the config settings
my $got_from_function  = get_names_for_orderimporter_preparser($schema);

my $expected ={
    tender_type => {
        klarna  => 'Card'
    },
};

cmp_deeply($got_from_function, $expected, " Config has correct value for 'OrderImporterPreParser'");


done_testing;



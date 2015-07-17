#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;
use Test::MockObject;

use Test::XT::BlankDB;

use XTracker::Database 'xtracker_schema';

# evil globals
our (%columns);

BEGIN {
    %columns = (
        designer           => [ qw( id designer url_key ) ],
        designer_state     => [ qw( designer state num_products num_comingsoon channel_id ) ],
    );

    use_ok('XTracker::Schema');
    use_ok('XTracker::Handler');
    use_ok('XTracker::DB::Factory::Designer');
}

# get a schema to query
my $schema = xtracker_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

#--------------- Run TESTS ---------------

_test_passive_factory_not_blankdb_dependant($schema,1);
_test_passive_factory_blankdb_dependant($schema, ! Test::XT::BlankDB::check_blank_db($schema));

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_passive_factory_not_blankdb_dependant {
    my $schema = shift;

    SKIP: {
        skip '_test_passive_factory_not_blankdb_dependant',8 if (!shift);

        my $desi_rs = $schema->resultset('Public::Designer');
        isa_ok($desi_rs, 'XTracker::Schema::ResultSet::Public::Designer',"Designer Result Set");

        my $des_channel = $schema->resultset('Public::DesignerChannel');
        isa_ok($des_channel,'DBIx::Class::ResultSet',"Designer Channel Result Set");

        my $attr_rs = $schema->resultset('Designer::Attribute');
        isa_ok($attr_rs, 'DBIx::Class::ResultSet',"Designer Attribute Result Set");

        my $factory =  XTracker::DB::Factory::Designer->new({ schema => $schema });
        isa_ok($factory,'XTracker::DB::Factory::Designer',"Designer Factory Set");


        isa_ok($desi_rs,'DBIx::Class::ResultSet',"Designer List");
        my @columns = $desi_rs->result_source->columns;
        is_deeply(\@columns,$columns{designer},"Designer Columns");


        my $desi_state_rs = $schema->resultset( 'DesignerState' )->search( {}, { 'select' => [ qw( designer state num_products num_comingsoon channel_id ) ] } );
        isa_ok($desi_state_rs,'DBIx::Class::ResultSet',"Deisgner State");
        my $desi_states = $desi_state_rs->search();
        isa_ok($desi_states,'XTracker::Schema::ResultSet::Public::Designer',"Deisgner State Result");
    };
}

sub _test_passive_factory_blankdb_dependant {
    my $schema = shift;

    SKIP: {
        skip '_test_passive_factory_blankdb_dependant',7 if (!shift);

        my $desi_rs = $schema->resultset('Public::Designer');
        isa_ok($desi_rs, 'XTracker::Schema::ResultSet::Public::Designer',"Designer Result Set");

        isa_ok($desi_rs,'DBIx::Class::ResultSet',"Designer List");
        my $desi_count = $desi_rs->count;
        cmp_ok($desi_count,">",1,"Designer List Count");
        my $desi = $desi_rs->first;
        isa_ok($desi,'XTracker::Schema::Result::Public::Designer',"Designer Record");
        my @columns = $desi->result_source->columns;
        is_deeply(\@columns,$columns{designer},"Designer Columns");


        my $desi_state_rs = $schema->resultset( 'DesignerState' )->search( {}, { 'select' => [ qw( designer state num_products num_comingsoon channel_id ) ] } );
        my $desi_states = $desi_state_rs->search();
        my $desi_state = $desi_states->first;
        isa_ok($desi_state,'XTracker::Schema::Result::Public::Designer',"Designer State Record");
        foreach my $col ( @{ $columns{designer_state} } ) {
            $desi_state->get_column($col);
        }
        pass("Designer State Columns");
    };
}

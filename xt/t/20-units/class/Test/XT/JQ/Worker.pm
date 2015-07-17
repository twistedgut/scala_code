package Test::XT::JQ::Worker;

use NAP::policy 'test';

use parent 'NAP::Test::Class';

use XT::JQ::Worker;
use XTracker::Database qw/xtracker_schema transaction_handle/;

=head1 NAME

Test::XT::JQ::Worker

=cut

# Let's just write a couple of tests to check that our db connections are
# created correctly
sub test_db_connections : Tests {
    my $self = shift;

    for (
        [ new_no_args =>
            sub { {} }, 1
        ],
        [ new_with_schema =>
            sub { { schema => xtracker_schema } }, 0
        ],
        [ new_with_autocommit_dbh =>
            sub { { dbh => xtracker_schema->storage->dbh } }, 0
        ],
        [ new_with_autocommit_off_dbh =>
            sub { { dbh => transaction_handle } }, 0
        ],
    ) {
        # The args need to be created as a sub so we can instiantiate the dbhs
        # in the inner subs and they get correctly re-created after being
        # cleared
        my ( $test_name, $arg_sub, $expected_is_schema_built_by_class ) = @$_;
        # As the subs are lazy we want to test that the worker is created with
        # the correct dbhs regardless of whether we call schema or dbh first
        for my $build_first ( qw/schema dbh/ ) {
            subtest "$test_name build $build_first first" => sub {
                my $worker = XT::JQ::Worker->new(%{$arg_sub->()});

                $worker->$build_first;

                is( $worker->schema->storage->dbh, $worker->dbh,
                    "dbh and schema's dbh should match" );

                # Make sure we clear our singletons
                XTracker::Database::clear_xtracker_schema;
                XTracker::Database::clear_xtracker_dbh_no_autocommit;
            };
        }
    }
}

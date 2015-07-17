#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use_ok( 'Test::XTracker::Data' );
use_ok( 'Path::Class::File' );
use_ok( 'Test::XTracker::Utils' );

my $schema = Test::XTracker::Data->get_schema;

isa_ok( $schema, 'XTracker::Schema' );

=head2 DESCRIPTION

Some tables are required to contain static lookup data, this tests that
those tables contain the expected data.

It takes config from the JSON file 't/data/expected_database_content.json'
with expected columns and rows.

To make looking up data easier, you can specify a relationship name to use
instead of the column name, this is in the following format:

    "relationships": {
        "some_column_id": [ "relationship_name", "other_column" ]
    }

Where 'some_column_id' is the column in the local table and 'other_column'
is the column in the foreign table 'relationship_name'.

=cut

my $file = Path::Class::File->new( 't/data/expected_database_content.json' );
my $resultsets = Test::XTracker::Utils->slurp_json_file($file);

foreach my $resultset_name ( sort keys %$resultsets ) {

    my $config = $resultsets->{ $resultset_name };

    subtest $resultset_name => sub {

        # Make sure we have the required config.
        is( ref( $config->{columns} ), 'ARRAY', 'We have column config' );
        is( ref( $config->{rows} ), 'ARRAY', 'We have row config' );

        # Get the config.
        my @columns       = @{ $config->{columns} };
        my @rows          = @{ $config->{rows} };
        my %relationships = ref( $config->{relationships} ) eq 'HASH'
            ? %{ $config->{relationships} }
            : ();

        # Make sure we have at least one column/row definition.
        cmp_ok( @columns, '>', 0, 'We have column definitions' );
        cmp_ok( @rows, '>', 0, 'We have row definitions' );

        # Get the resultset.
        my $resultset = $schema->resultset( $resultset_name );
        isa_ok( $resultset, 'DBIx::Class::ResultSet' );

        my @search_columns;
        my @search_joins;

        foreach my $column_name ( @columns ) {
            # Check each column and add to column/join arrays.

            my $column_exists = $resultset->result_source->has_column( $column_name );
            ok( $column_exists, "Column $column_name exists" );

            if ( $column_exists ) {
                # Check the column is valid.

                if ( exists $relationships{ $column_name } && ref( $relationships{ $column_name } ) eq 'ARRAY' ) {
                    # If a relationship is specified, add to the join and search clauses.

                    # Relationship values require two parameters, the foreign table and column.
                    my @relationship = @{ $relationships{ $column_name } };
                    cmp_ok( scalar @relationship, '==', 2, 'We have the right number of relationship values' );

                    push @search_columns, join( '.', @relationship );
                    push @search_joins, $relationship[0];

                } else {
                    # Otherwise just add the column name as it is.

                    push @search_columns, $column_name;

                }

            }

        }

        my $count = 0;

        foreach my $row ( @rows ) {
            # Check each row exists.

            my $search = $resultset->search( {
                map { $search_columns[$_] => $row->[$_] }
                    ( 0 .. $#search_columns ),
            },{
                join => \@search_joins,
            } );

            if ( $search->count == 1 ) {

                $count++;

            } else {
                # If we didn't find the row, fail and explain which one.

                fail 'Found matching row';
                diag explain $row;

            }

        }

        cmp_ok( $count, '==', scalar @rows, 'We found ' . ( scalar @rows ) . ' rows as expected' );

    };

}

done_testing;


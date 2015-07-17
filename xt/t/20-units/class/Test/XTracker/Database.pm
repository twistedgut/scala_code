package Test::XTracker::Database;

use FindBin::libs;
use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

use XTracker::Config::Local;
use XTracker::Database qw<
    clear_xtracker_schema
    read_handle
    schema_handle
    transaction_handle
    xtracker_schema
>;

=head1 NAME

Test::XTracker::Database - Unit tests for L<XTracker::Database>

=head1 DESCRIPTION

Unit tests for L<XTracker::Database>.

=cut

sub setup : Tests {
    my $self = shift;

    # Reset our singleton variables
    XTracker::Database::clear_xtracker_schema;
    XTracker::Database::clear_xtracker_dbh_no_autocommit;

    $self->SUPER::setup;
}

sub test_clear_xtracker_schema : Tests {
    my $self = shift;

    my $dbh_ref = xtracker_schema()->storage->dbh;
    clear_xtracker_schema();
    isnt( xtracker_schema()->storage->dbh, $dbh_ref,
        'clear_xtracker_schema unsets singleton' );
}

sub test_clear_xtracker_dbh_no_autocommit : Tests {
    my $self = shift;

    my $dbh_ref = XTracker::Database::xtracker_dbh_no_autocommit();
    XTracker::Database::clear_xtracker_dbh_no_autocommit();
    isnt( XTracker::Database::xtracker_dbh_no_autocommit(), $dbh_ref,
        'clear_xtracker_dbh_no_autocommit unsets singleton' );
}

sub test_xtracker_autocommit_on_singleton : Tests {
    my $self = shift;

    isa_ok( my $schema = xtracker_schema(), 'DBIx::Class::Schema' );
    is( xtracker_schema(), $schema,
        'calling xtracker_schema() again should return singleton object' );
    is( schema_handle(), $schema,
        'calling schema_handle() should return singleton object' );
    is( read_handle(), $schema->storage->dbh,
        'calling read_handle() should return singleton object' );

    for my $db_connection ( qw{xtracker xtracker_schema} ) {
        is( XTracker::Database::get_schema_using_dbh($schema->storage->dbh, $db_connection),
            $schema,
            "get_schema_using_dbh with '$db_connection' should return singleton object"
        );

        eq_or_diff(
            [XTracker::Database::get_schema_and_ro_dbh($db_connection)],
            [$schema, $schema->storage->dbh],
            "get_schema_and_ro_dbh with '$db_connection' should return schema singleton"
        );
    }
}

sub test_xtracker_autocommit_off_singleton : Tests {
    my $self = shift;

    my $schema = xtracker_schema();
    isa_ok( my $no_ac_dbh = transaction_handle(), 'DBI::db' );
    isnt( $no_ac_dbh, $schema->storage->dbh,
        'transaction_handle() should return a no autocommit DBI object' );
    is( transaction_handle(), $no_ac_dbh,
        'calling transaction_handle again should return singleton object' );

    warning_like(
        sub { XTracker::Database::get_schema_using_dbh($no_ac_dbh, 'xtracker_schema') },
        qr{autocommit},
        'get_schema_using_dbh for a dbh with autocommit turned off should trigger a warning'
    );

    warning_like(
        sub {
            XTracker::Database::get_database_handle({
                name => 'xtracker_schema', type => 'readonly',
            })
        },
        qr{Don't pass 'type'},
        'calling get_database_handle for a schema object with autocommit off should trigger a warning'
    );
    warnings_like(
        sub {
            XTracker::Database::get_database_handle({
                name => 'xtracker_schema', type => 'transaction',
            })
        },
        [ qr{Don't pass 'type'}, qr{Attempted to get a schema handle with autocommit off} ],
        'calling get_database_handle for a schema object with autocommit off should trigger warnings'
    );
}

# TODO: This should probably live under t/10-env
sub test_db_configs : Tests {
    my $self = shift;

    my %config = XTracker::Config::Local::load_config;

    # Not a fantastically useful test as in our test env we only really have
    # xtracker, and most of the mysql configs actually use a Mock db type, but
    # the following is useful as a basic sanity test
    for my $db_section ( map { m{^Database_(.+)$} } keys %config ) {
        # We have a couple of entries in our config that don't use
        # get_database_handle to generate their dsn - let's skip these (we can
        # identify them by their lack of _readonly or _transaction keys)
        next unless @{$config{"Database_$db_section"}}{qw/db_user_readonly db_user_transaction/};
        # We also skip 'other dc' and fulcrum db entries, as these won't be
        # available
        next if $db_section =~ m{^(?:XTracker_DC\d+|Fulcrum)$};

        for my $autocommit ( 0..1 ) {
            # DBIC configs with autocommit off throw warnings, don't test them
            # here
            next if $db_section =~ m{_schema_?} && !$autocommit;

            subtest "test $db_section with autocommit $autocommit" => sub {
                my $connection;
                lives_ok(
                    sub {
                        $connection = XTracker::Database::get_database_handle({
                            name => $db_section,
                            (!$autocommit ? (type => 'transaction') : ()),
                        });
                    }, "getting db handler should live",
                );

                # Set our $dbh here so we can test that the autocommit flag is set
                # correctly
                my $dbh;
                if ( $db_section =~ m{_schema_?} ) {
                    # DBIC warns if the db_type is 'Mock'; we don't need to
                    # test any further
                    return if $config{"Database_$db_section"}{db_type} eq 'Mock';
                    isa_ok( $connection, 'DBIx::Class::Schema' );
                    $dbh = $connection->storage->dbh;
                }
                else {
                    isa_ok( $connection, 'DBI::db' );
                    $dbh = $connection;
                }
                ok(
                    ($autocommit ? $dbh->{AutoCommit} : !$dbh->{AutoCommit}),
                    "dbh's autocommit should be $autocommit"
                );
            };
        }
    }
    return;
}


# test to check if the db timezone has been set correctly
sub test_db_timezone : Tests {
    my $self = shift;

    my $schema = xtracker_schema();
    my $dbh = $schema->storage->dbh;

    my $db_timezone = _get_db_timezone($dbh);

    is($db_timezone, config_var('DistributionCentre', 'timezone'),
        "Timezone set correctly: $db_timezone for " . config_var('DistributionCentre', 'name'));
}


sub _get_db_timezone {
    my ($dbh) = @_;

    my $qry = 'SHOW timezone';

    my $sth = $dbh->prepare( $qry );
    $sth->execute();

    return $sth->fetchrow();
}

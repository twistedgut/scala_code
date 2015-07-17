package Test::XTracker::Schema;

use NAP::policy qw/test class/;
BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::WithSchema';
};

=head1 NAME

Test::XTracker::Schema

=head1 DESCRIPTION

Tests custom Methods that have been added to the 'XTracker::Schema' Class.

=cut

use DateTime::TimeZone;

use Test::XTracker::Data;

use XTracker::Config::Local 'config_var';
use XTracker::Database          qw( schema_handle );
use XT::AccessControls;

=head1 TESTS

=head2 test_db_now

Tests the 'db_now' method.

=cut

sub test_db_now : Tests() {
    my $self = shift;
    isa_ok( my $now = $self->schema->db_now, 'DateTime' );

    # We currently set the database connection's timezone to be the one
    # specified in the DC's config - as we have some code (case in point the
    # manifest page date dropdown) that relies on this timezone being set to
    # that, we should really test this too.
    my $expected_timezone = config_var(qw/DistributionCentre timezone/);
    my $expected_offset = DateTime::TimeZone->new( name => $expected_timezone)
        ->offset_for_datetime($now);
    is( $now->time_zone->offset_for_datetime($now), $expected_offset,
        "db_now in correct time zone ($expected_timezone - offset $expected_offset)" );
}

=head2 test_db_now_raw

=cut

sub test_db_now_raw : Tests {
    my $self = shift;
    my $schema = $self->schema;
    ok($schema->parse_datetime( $schema->db_now_raw ),
        $schema->datetime_parser . ' can parse return value');
}

=head2 test_db_clock_timestamp

=cut

sub test_db_clock_timestamp : Tests {
    my $self = shift;
    my $schema = $self->schema;
    $schema->txn_do(sub{
        isa_ok( my $now = $schema->db_clock_timestamp, 'DateTime' );
        isa_ok( my $later = $schema->db_clock_timestamp, 'DateTime' );
        cmp_ok( $now, q{<}, $later,
            'second db_clock_timestamp call in transaction should be later than first'
        ) or diag sprintf q{now is '%s', later is '%s'},
            map { $_->strftime('%F %R.%6N%z')} $now, $later;
    });
}

=head2 test_acl

Tests the 'acl' method which is used to get an instance of 'XT::AccessControls'
that can be assigned to the 'XTracker::Schema' class.

=cut

sub test_acl : Tests() {
    my $self    = shift;

    # get a new Schema connection so as to
    # not interfere with the global one
    my $schema  = schema_handle();

    my $operator    = $schema->resultset('Public::Operator')
                                ->search->first;
    my $session     = {
        acl => {
            operator_roles  => [ 'can_do' ],
        },
    };

    my $acl = XT::AccessControls->new( {
        operator    => $operator,
        session     => $session,
    } );

    ok( $schema->can('set_acl'), "'XTracker::Schema' has a 'set_acl' method" );
    ok( $schema->can('clear_acl'), "'XTracker::Schema' has a 'clear_acl' method" );
    ok( $schema->can('acl'), "'XTracker::Schema' has an 'acl' method" );

    throws_ok {
        $schema->set_acl( $operator );
    } qr/must be .*'XT::AccessControls' class/i,
            "using 'set_acl' with a non 'XT::AccessControls' object throws an Error";

    lives_ok {
        $schema->set_acl( $acl );
    } "using 'set_acl' with a proper 'XT::AccessControls' object is ok";

    isa_ok( $schema->acl, 'XT::AccessControls', "'\$schema->acl' returns the object" );

    lives_ok {
        $schema->acl->operator_has_the_role('can_do');
    } "and can use a method from 'XT::AccessControls'";

    lives_ok {
        $schema->clear_acl;
    } "can call 'clear_acl'";

    ok( !defined $schema->acl, "'\$schema->acl' is now 'undef'" );
}


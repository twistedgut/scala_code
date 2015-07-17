package Test::XT::DC::Controller::API::StockControl::Reservation::Reassign;
use NAP::policy 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::XT::DC::Controller::API::StockControl::Reservation::Reassign

=head1 DESCRIPTION

Tests the L<XT::DC::Controller::API::StockControl::Reservation::Reassign>
class.

=cut

use JSON;
use Catalyst::Test 'XT::DC';
use HTTP::Request::Common;
use Test::XT::Data;
use Test::XTracker::Data;
use Test::XTracker::Data::Operator;
use Mock::Quick;
use XTracker::Constants::FromDB qw( :authorisation_level :department );

=head1 TESTS

=cut

sub test_setup :Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{data} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::ReservationSimple' ],
    );

    $self->schema->txn_begin;

    $self->{logged_in_operator} = Test::XTracker::Data::Operator->create_new_operator({
        username        => 'test.one',
        name            => 'Test One',
        department_id   => $DEPARTMENT__PERSONAL_SHOPPING,
    });

    $self->{replacement_operator} = Test::XTracker::Data::Operator->create_new_operator({
        username        => 'test.two',
        name            => 'Test Two',
        department_id   => $DEPARTMENT__PERSONAL_SHOPPING,
    });

    Test::XTracker::Data->grant_permissions(
        $self->logged_in_operator->id,
        'Stock Control',
        'Reservation',
        $AUTHORISATION_LEVEL__MANAGER
    );

    $self->{has_permission} = 1;

    # Fake the response from the ACL has_permission method, so we can test
    # the API with and without permissions.
    $self->{acl} = qtakeover( 'XT::AccessControls' );
    $self->{acl}->override( has_permission => sub { return $self->{has_permission} } );

    # We're not testing authentication, so this just returns static data.
    $self->{xtdc} = qtakeover( 'XT::DC' );
    $self->{xtdc}->override( session => sub { return {
        operator_id => $self->logged_in_operator->id,
        user_id     => $self->logged_in_operator->username,
        acl         => { operator_roles => [] },
    }});

}

sub test_teardown :Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    # Explicitly restore the mocked methods.
    $self->{xtdc} = undef
    $self->{acl} = undef;

    $self->schema->txn_rollback;

    # Explicitly unsetting this, because after creating new operators which
    # are used in the session, they get left around in the schema object
    # which causes problems in class tests. See XTracker::Schema for details.
    #
    # This was noticed when a following test fell over when trying to create
    # an audit.recent record, which occurs when products are created and
    # "DBIx::Class::AuditLog" (a component loaded by Public::Product) tries
    # to create an audit trail.
    $self->schema->operator_id( undef );

}

=head2 test_field_values

Test that the API returns a Bad Request (400) when any of the fields are
missing or contain invalid data.

=cut

sub test_field_values :Tests {
    my $self = shift;

    my $reservation = $self->data->reservation;

    my $invalid_reservation_id  = $self->invalid_id_for_resultset('Public::Reservation');
    my $invalid_operator_id     = $self->invalid_id_for_resultset('Public::Operator');

    my %tests = (
        'Missing reservation field' => {
            expected    => { error => 'Missing Key: reservation_id' },
            payload     => {
                new_operator_id => $self->replacement_operator->id,
            },
        },
        'Missing operator field' => {
            expected    => { error => 'Missing Key: new_operator_id' },
            payload     => {
                reservation_id  => $reservation->id,
            },
        },
        'Invalid reservation field' => {
            expected    => { error => 'Invalid Key: reservation_id' },
            payload     => {
                reservation_id  => 'NOT A VALID DATABASE ID',
                new_operator_id => $self->replacement_operator->id,
            },
        },
        'Invalid operator field' => {
            expected    => { error => 'Invalid Key: new_operator_id' },
            payload     => {
                reservation_id  => $reservation->id,
                new_operator_id => 'NOT A VALID DATABASE ID',
            },
        },
        'Missing reservation record' => {
            expected    => { error => 'A record for reservation_id "' . $invalid_reservation_id . '" does not exist' },
            payload     => {
                reservation_id  => $invalid_reservation_id,
                new_operator_id => $self->replacement_operator->id,
            },
        },
        'Missing operator record' => {
            expected    => { error => 'A record for new_operator_id "' . $invalid_operator_id . '" does not exist' },
            payload     => {
                reservation_id  => $reservation->id,
                new_operator_id => $invalid_operator_id,
            },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {
        subtest $name => sub {
            $self->post_to_api_ok( $test->{payload}, 400, $test->{expected} );
        };
    }

}

=head2 test_not_allowed_to_change_reservation

The reservation's operator can only be updated under certain circumstances,
this checks this with one particular case, namely the operator's department
being 'Finance' instead of 'Personal Shopping'. A Bad Request (400) should be
returned.

=cut

sub test_not_allowed_to_change_reservation :Tests {
    my $self = shift;

    my $reservation         = $self->data->reservation;
    my $permission_error    = sprintf( q{Failed to transfer reservation "%u" from operator "%s" to operator "%s", because the operator '%s' must be in one of the following departments: Customer Care, Customer Care Manager, Personal Shopping or Fashion Advisor},
        $reservation->id,
        $reservation->operator->name,
        $self->replacement_operator->name,
        $self->logged_in_operator->name );

    # An operator in the Finance department cannot update the reservation's
    # operator.
    $self->logged_in_operator->update({
        department_id => $DEPARTMENT__FINANCE,
    });

    $self->post_to_api_ok({
        reservation_id  => $reservation->id,
        new_operator_id => $self->replacement_operator->id,
    }, 400, { error => $permission_error } );

}

=head2 test_reservation_not_updated

Test that we get a Bad Request (400) if the update does nothing, in this case,
we change the operator to what it already is.

=cut

sub test_reservation_not_updated :Tests {
    my $self = shift;

    my $reservation     = $self->data->reservation;
    my $update_error    = sprintf( 'Failed to transfer reservation "%u" from operator "%s" to operator "%s", because the reservation is already assigned to the requested operator',
        $reservation->id,
        $reservation->operator->name,
        $reservation->operator->name );

    $self->post_to_api_ok({
        reservation_id  => $reservation->id,
        new_operator_id => $reservation->operator->id,
    }, 400, { error => $update_error } );

}

=head2 test_reservation_update_dies

Test we get a Bad Request (400) if the API dies in any way.

=cut

sub test_reservation_update_dies :Tests {
    my $self = shift;

    my $reservation = $self->data->reservation;

    my $mock = qtakeover('XTracker::Schema::Result::Public::Reservation');
    $mock->override( update_operator => sub { die 'TEST' } );

    $self->post_to_api_ok({
        reservation_id  => $reservation->id,
        new_operator_id => $self->replacement_operator->id,
    }, 400, { error => 'There was a problem processing the request' } );

}

=head2 test_no_permission

Test we get an Access Denied (401) when we don't have permission to use the
API.

=cut

sub test_no_permission :Tests {
    my $self = shift;

    my $reservation = $self->data->reservation;

    $self->{has_permission} = 0;

    my ( $code, $response ) = $self->post_to_api_ok({
        reservation_id  => $reservation->id,
        new_operator_id => $self->replacement_operator->id,
    }, 401, { error => 'Access Denied' } );

}

=head2 test_reservation_success

Test that under normal circumstances we get an OK (200).

=cut

sub test_reservation_success :Tests {
    my $self = shift;

    my $reservation = $self->data->reservation;

    $self->post_to_api_ok({
        reservation_id  => $reservation->id,
        new_operator_id => $self->replacement_operator->id,
    }, 200, { status => 'SUCCESS' } );

}

=head1 METHODS

=head2 post_to_api_ok( $payload, $expected_code, $expected_response )

Make a POST request to the API with the given C<$payload> and test that we
get the C<$expected_code> and C<$expected_response> back.

=cut

sub post_to_api_ok {
    my $self = shift;
    my ( $payload, $expected_code, $expected_response ) = @_;

    my $response = request
        POST '/API/StockControl/Reservation/Reassign',
            'X-Requested-With'  => 'XMLHttpRequest',
            'Content-Type'      => 'application/json',
            'Content'           => encode_json( $payload );

    cmp_ok( $response->code, '==', $expected_code,
        "Got response code '$expected_code' as expected" );

    cmp_deeply( decode_json($response->content), $expected_response,
        'The response is also as expected' );

    return;

}

=head2 invalid_id_for_resultset( $resultset )

Return a non-existant ID for a given C<$resultset>.

=cut

sub invalid_id_for_resultset {
    my $self = shift;
    my ( $resultset ) = @_;

    return $self->schema->resultset( $resultset )
        ->get_column('id')
        ->max + 1;

}

=head1 ACCESSORS

=over

=item data

=item schema

=item logged_in_operator

=item replacement_operator

=back

=cut

sub data                    { return shift->{data} }
sub schema                  { return shift->{data}->schema }
sub logged_in_operator      { return shift->{logged_in_operator} }
sub replacement_operator    { return shift->{replacement_operator} }


#!/usr/bin/env perl
use NAP::policy qw( test class );
BEGIN { extends 'NAP::Test::Class' }

use Test::XT::Flow;
use Test::XTracker::Data::Reservation;
use Test::XTracker::Data::Operator;

use XTracker::Constants::FromDB qw(
    :authorisation_level
);

=head1 NAME

t/30-functional/cando/customercare/reservation_bulk_reassign.t

=head1 DESCRIPTION

Tests the 'Bulk Reassign' page, under Stock Control -> Reservations.

=head1 TESTS

=head2 test_startup

Create Two new Reservations assigned to two new Operators.

=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;

    use_ok('XT::DC::Controller::StockControl::Reservation::BulkReassign');

    $self->{role_name}      = 'app_canBulkReassignReservations';
    $self->{operators}      = [ map { Test::XTracker::Data::Operator->create_new_operator } 1..2 ];
    $self->{reservations}   = [ Test::XTracker::Data::Reservation->create_reservations( 2 ) ];

    # Update the reservations to be assigned to different operators.
    $self->reservation_1->update({ operator_id => $self->operator_1->id });
    $self->reservation_2->update({ operator_id => $self->operator_2->id });

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Reservations',
        ],
    );

}

=head2 test_permission_failure

Test that without the required role we cannot access the page.

=cut

sub test_permission_failure : Tests {
    my $self = shift;

    $self->login( $self->operator_1, 0 );

    $self->{framework}->catch_error(
        qr/You don't have permission to access Reservation in Stock Control/,
        'Cannot see Bulk Reassign Page without correct permisions',
        'mech__reservation__bulk_reassign' );

}

=head2 test_current_operator

Test that with the appropriate role, the default view of the page returns all
the reservations for the current operator.

=cut

sub test_current_operator : Tests {
    my $self = shift;

    $self->login( $self->operator_1, 1 );

    $self->framework->mech__reservation__bulk_reassign;
    $self->reservation_list_ok( $self->reservation_1 );

}

=head2 test_alternative_operator

Test that with the appropriate role, the page returns all
the reservations for the selected operator.

=cut

sub test_alternative_operator : Tests {
    my $self = shift;

    $self->login( $self->operator_1, 1 );

    $self->framework
        ->mech__reservation__bulk_reassign
        ->mech__reservation__bulk_reassign__operator_submit({ operator => $self->operator_2->id });

    $self->reservation_list_ok( $self->reservation_2 );

}

=head1 METHODS

=head2 login( $operator, $with_role )

Login with the given C<$operator> and if C<$with_role> is TRUE, grant the
C<$operator> the role specified by C<role_name>.

=cut

sub login {
    my $self = shift;
    my ( $operator, $with_role ) = @_;

    note 'Logging In:';
    note '  With Operator "' . $operator->username . '" (' . $operator->id . ')';
    note '  With Role "'  . ( $with_role ? $self->role_name : '<NONE>' ) . '"';

    my $auth = {
        user    => $operator->username,
        passwd  => $operator->password,
    };

    my $roles = {
        names => [ $self->role_name ],
    };

    $self->framework->login_with_permissions({
        auth => $auth,
        $with_role ? ( roles => $roles ) : (),
    });

}

=head2 reservation_list_ok( $reservation )

Test the list of reservations on the page contains only the given
C<$reservation> and all the fields are correct.

=cut

sub reservation_list_ok {
    my $self = shift;
    my ( $reservation ) = @_;

    $reservation->discard_changes;

    my $expected = [ {
        SELECT_ALL  => ignore(),
        RESULT      => ignore(),
        Reservation => $reservation->id,
        Created     => $reservation->date_created ? $reservation->date_created->dmy : '',
        Expires     => $reservation->date_expired ? $reservation->date_expired->dmy : '',
        Uploaded    => $reservation->date_uploaded ? $reservation->date_uploaded->dmy : '',
        Source      => $reservation->reservation_source ? $reservation->reservation_source->source : '',
        Status      => $reservation->status->status,
        Type        => $reservation->reservation_type ? $reservation->reservation_type->type : '',
        Customer    => {
            url     => '/CustomerCare/OrderSearch/CustomerView?customer_id=' . $reservation->customer->id,
            value   => $reservation->customer->display_name,
        },
    } ];

    cmp_deeply(
        $self->framework->mech->as_data->{reservation_list},
        $expected, 'Got the correct list of reservations' );

}

=head1 ACCESSORS

=over 4

=item framework

The L<Test::XT::Flow> framework.

=item operator_1 / operator_2

The two operators.

=item reservation_1 / reservation_2

The two reservations.

=item role_name

The name of the role that protects the page.

=back

=cut

sub framework       { return shift->{framework} }
sub operator_1      { return shift->{operators}->[0] }
sub operator_2      { return shift->{operators}->[1] }
sub reservation_1   { return shift->{reservations}->[0] }
sub reservation_2   { return shift->{reservations}->[1] }
sub role_name       { return shift->{role_name} }

Test::Class->runtests;

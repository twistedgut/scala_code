package XT::DC::Controller::StockControl::Reservation::BulkReassign;
use NAP::policy 'class';

BEGIN { extends 'Catalyst::Controller' }

use XTracker::Navigation qw( build_sidenav );
use XTracker::Logfile qw( xt_logger );
use XTracker::Constants::FromDB qw( :department );

=head1 NAME

XT::DC::Controller::StockControl::Reservation::BulkReassign - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 root

Controller for the following URL:

    /StockControl/Reservation/BulkReassign

=cut

sub root :Path('/StockControl/Reservation/BulkReassign') {
    my ( $self, $c ) = @_;

    $c->check_access;

    $c->stash(
        template            => 'reservation/bulk_reassign.tt',
        section             => 'Reservation',
        subsection          => 'Actions',
        subsubsection       => 'Bulk Reassign',
        css                 => '/css/preorder.css',
        js                  => [
            '/javascript/jquery.qjax.min.js',
            '/javascript/api_queue.js',
            '/javascript/preorder/bulk-reassign.js',
            '/javascript/feedback.js',
            '/javascript/xui.js',
        ],
        sidenav             => build_sidenav({
            navtype    => 'reservations',
            res_filter => 'Personal'
        }),
    );

    try {

        my $operator_id = $c->request->param('operator')
            ? $c->request->param('operator')
            : $c->session->{operator_id};

        my $reservations;
        my $operator = $c->model('DB::Public::Operator')->find( $operator_id );

        if ( $operator ) {

            $reservations = $operator
                ->reservations
                ->pending_and_uploaded;

        } else {

            $c->feedback_error( "Operator ID '$operator_id' not found" );

        }

        # Get a list of all operators in PS and FA departments.
        my $show_operators = $c->model('DB::Public::Operator')->in_department([
            $DEPARTMENT__PERSONAL_SHOPPING,
            $DEPARTMENT__FASHION_ADVISOR
        ]);

        # It doesn't make sense to reassign a reservation to the same operator.
        my $reassign_operators = $show_operators
            ->search({ id => { '!=' => $operator_id } });

        $c->stash(
            reservations        => [ defined $reservations ? $reservations->all : () ],
            show_operators      => [ defined $show_operators ? $show_operators->all : () ],
            reassign_operators  => [ defined $reassign_operators ? $reassign_operators->all : () ],
            current_operator    => $operator,
        );

    } catch {

        $c->feedback_fatal('There was a problem displaying this page');
        xt_logger->fatal( "Error in 'Pre-Order Bulk Reassignment' page: $_" );

    };

    return;

}

=encoding utf8

=head1 AUTHOR

Andrew Benson

=cut

__PACKAGE__->meta->make_immutable;

1;

package XT::DC::Controller::PreOrder::BulkRelease;
use NAP::policy 'class';

BEGIN { extends 'Catalyst::Controller' }

use XTracker::Logfile qw( xt_logger );
use XTracker::Error;
use XTracker::Navigation qw( build_sidenav );
use XTracker::Constants::FromDB qw( :department );

=head1 NAME

XT::DC::Controller::PreOrder::BulkRelease

=head1 DESCRIPTION

Controller for the following URLs:

    /StockControl/Reservation/PreOrder/PreOrderOnhold

=head1 METHODS

=head2 root

URL: /StockControl/Reservation/PreOrder/PreOrderOnhold

=cut

sub root :Path('/StockControl/Reservation/PreOrder/PreOrderOnhold') {
    my ($self, $c) = @_;

    $c->check_access('Stock Control', 'Reservation');

    $c->stash(
        template            => 'reservation/pre_order_on_hold.tt',
        section             => 'Reservation',
        subsection          => "PreOrder's",
        subsubsection       => 'OnHold',
        css                 => '/css/preorder.css',
        js                  => [
            '/javascript/jquery.qjax.min.js',
            '/javascript/api_queue.js',
            '/javascript/preorder/preorder-onhold.js',
            '/javascript/feedback.js',
            '/javascript/xui.js',
        ],
        sidenav             => build_sidenav({
            navtype    => 'reservations',
            res_filter => 'Personal'
        }),
    );

    try {

        my $operator_id = $c->request->param('alt_operator_id')
            ? $c->request->param('alt_operator_id')
            : $c->session->{operator_id};

        my $operator = $c->model('DB::Public::Operator')->find( $operator_id );

        # Get a list of all operators in PS and FA departments.
        my $operators = $c->model('DB::Public::Operator')->in_department([
            $DEPARTMENT__PERSONAL_SHOPPING,
            $DEPARTMENT__FASHION_ADVISOR
        ]);

        my $exported_pre_orders_on_hold = $operator
            ->pre_orders
            ->get_exported_pre_orders_on_hold
            ->search( undef, {
                order_by => 'orders.order_nr',
                prefetch => {
                    link_orders__pre_orders => {
                    orders => {
                    link_orders__shipments => {
                    shipment =>
                    'shipment_items'
                }}}},
            });

        $c->stash(
            pre_orders          => [ $exported_pre_orders_on_hold->all ],
            all_operators       => [ $operators->all ],
            current_operator    => $operator,
        );

    } catch {

        $c->feedback_fatal('There was a problem displaying this page');
        xt_logger->fatal( "Error in 'Pre-Orders on Hold' page: $_" );

    };

    return;

}

1;

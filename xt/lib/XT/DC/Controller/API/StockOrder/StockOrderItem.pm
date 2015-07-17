package XT::DC::Controller::API::StockOrder::StockOrderItem;

use NAP::policy "tt", 'class';

BEGIN {
    extends 'Catalyst::Controller::REST';
}

__PACKAGE__->config(
    path        => 'api/stock-orders/stock_order_item',
);

=head1 NAME

XT::DC::Controller::StockOrder::StockOrderItem - Catalyst REST controller for stock orders

=head1 DESCRIPTION

This controller provides a RESTful interface to stock orders in the DC database

=head1 ACTIONS

=head2 root

=cut

sub root :Chained('/') :PathPrefix :CaptureArgs(0) { }

sub stock_order_item :Chained('root') :PathPart('') :ActionClass('REST') :Args(1) {
    my ($self, $c, $stock_order_item_id) = @_;
    if (my $stock_order_item = $c->model('DB::Public::StockOrderItem')->find($stock_order_item_id)) {
        $c->stash(stock_order_item => $stock_order_item);
    }
    else {
        $self->status_not_found($c,
            message => "Stock order ID: $stock_order_item_id not found" ,
        );

        $c->detach;
    }
}

sub stock_order_item_GET {
    my ($self, $c) = @_;

    $c->stash(rest => { $c->stash->{stock_order_item}->get_columns });
}

=head1 SEE ALSO

L<XT::DC>, L<Catalyst::Controller::REST>, L<Catalyst::Controller>

=head1 AUTHOR

Pete Smith

=cut


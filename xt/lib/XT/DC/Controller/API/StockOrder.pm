package XT::DC::Controller::API::StockOrder;

use NAP::policy "tt", 'class';

BEGIN {
    extends 'Catalyst::Controller::REST';
}

__PACKAGE__->config(
    path        => 'api/stock-orders',
);

=head1 NAME

XT::DC::Controller::StockOrder - Catalyst REST controller for stock orders

=head1 DESCRIPTION

This controller provides a RESTful interface to stock orders in the DC database

=head1 ACTIONS

=head2 root

=cut

sub root :Chained('/') :PathPrefix :CaptureArgs(0) { }

sub stock_order :Chained('root') :PathPart('') :ActionClass('REST') :Args(1) {
    my ($self, $c, $stock_order_id) = @_;

    if (my $stock_order = $c->model('DB::Public::StockOrder')->find($stock_order_id)) {
        $c->stash(stock_order => $stock_order);
    }
    else {
        $self->status_not_found($c,
            message => "Stock order ID: $stock_order_id not found" ,
        );

        $c->detach;
    }
}

sub stock_order_GET {
    my ($self, $c) = @_;

    $c->stash(rest => { $c->stash->{stock_order}->get_columns });
    my $stockorder = $c->stash->{stock_order};
    my $stock_order_items = $stockorder->stock_order_items;

    my $data = { $stockorder->get_columns };

    while (my $stock_order_item = $stock_order_items->next) {
        push(
            @{ $data->{stock_order_items} },
            $c->uri_for_action('/api/stockorder/stockorderitem/stock_order_item', $stock_order_item->id)->as_string,
        );
    }

    my $product = $stockorder->product;
    push ( @{ $data->{product} },
   #        $c->uri_for_action('/api/stockorder/product', $product->id)->as_string,
            { $product->get_columns },
    );

    $c->stash(rest => $data);
}



=head1 SEE ALSO

L<XT::DC>, L<Catalyst::Controller::REST>, L<Catalyst::Controller>

=head1 AUTHOR

Pete Smith

=cut


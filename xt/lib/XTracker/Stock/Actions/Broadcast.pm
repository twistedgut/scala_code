package XTracker::Stock::Actions::Broadcast;
use NAP::policy "tt";
use XTracker::Error;

sub handler {
    my $request      = shift;
    my $handler      = XTracker::Handler->new($request);
    my $schema       = $handler->{schema};
    my $product_id   = $handler->{param_of}{product_id};
    my $redirect_url = "/StockControl/Inventory/Overview?product_id=$product_id";

    # Find the product (or voucher)
    my $product = $schema->resultset('Public::Product')->find($product_id)
        // $schema->resultset('Voucher::Product')->find($product_id);

    if ( $product ) {
        $product->broadcast_stock_levels();
        xt_success("Product stock broadcast successful");
    }
    else {
        xt_warn("Unable to update stock for product: $product_id");
    };

    return $handler->redirect_to( $redirect_url );
}

__END__

=pod

=head1 NAME

XTracker::Stock::Action::Broadcast - Handler for broadcasting stock levels

=head1 DESCRIPTION

When given a C<$product_id> via a form submission, locates the product object
and broadcasts its stock levels.

=head1 METHODS

=head2 C<handler>

Handles the form submission.

=cut

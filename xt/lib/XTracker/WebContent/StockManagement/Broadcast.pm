package XTracker::WebContent::StockManagement::Broadcast;
use NAP::policy "tt", 'class';
use XTracker::Logfile 'xt_logger';
use XTracker::Constants::FromDB ':variant_type';

with
    'XTracker::WebContent::Roles::ContentManager',
    'XTracker::WebContent::Roles::StockManager',
    'XTracker::WebContent::Roles::StockManagerWithMessages';
with 'XTracker::WebContent::Roles::DetailStockFields';

=head1 NAME

  XTracker::WebContent::StockManagement::Broadcast - publish detailed stock levels

=head1 DESCRIPTION

This is almost a L<XTracker::WebContent::StockManagement> plugin, in
the sense that it has the same API, but it won't be instantiated by
the factory (C<is_mystock> always returns false).

Actual plugins that consume
L<XTracker::WebContent::Roles::StockManagerBroadcast> will get an
instance of this class, and the C<stock_update>, C<commit> and
C<rollback> methods will be called on this instance after the ones
from the other plugin.

=head1 TODO / WARNING

http://jira4.nap/browse/PS-83 says to make sure this class is used
every time any quantity (or other stock level) record changes. We are
not doing it right now, since it's not strictly needed and it's a lot
of boring work.

The important number (C<saleable_quantity>) will be broadcast
correctly anyway, because the actual plugins are interested in that,
and they have been tested to send their messages at the right
times. Changes in other levels (the RTV ones, for example) may not be
broadcast in a timely fashion. They will, though, always contain
correct numbers at the time a message is actually sent.

Feel free to add calls to the L<XTracker::WebContent::StockManagement>
factory at any other place where stock is moved / changed, but make
sure it will not send out too many messages (this will probably
require some interesting fiddling with C<is_mystock> in all the plugins).

=cut

has '+message_type' => (
    default => 'XT::DC::Messaging::Producer::Stock::DetailedLevelChange',
);

sub is_mychannel { 0 } # we are only delegated to, never actually loaded by the factory

sub stock_update {
    my $self = shift;
    my $args = {
        quantity_change => undef,
        variant_id      => undef,
        product         => undef,
        full_details    => undef,
        @_
    };

    my $variant_id      = $args->{variant_id};
    my $product         = $args->{product};
    my $product_id      = $args->{product_id};
    my $full_details    = $args->{full_details};

    if ($product_id && !$product) {
        $product = $self->schema->resultset('Public::Product')
            ->find($product_id)
         || $self->schema->resultset('Voucher::Product')
             ->find($product_id);
    }
    if ($variant_id && !$product) {
        my $variant = $self->schema->resultset('Public::Variant')
            ->find($variant_id)
         || $self->schema->resultset('Voucher::Variant')
             ->find($variant_id);
        $product = $variant->product;
    }
    my $quantity_change = $args->{quantity_change};
    my $channel_id = $self->channel->id;

    my $new_stock_levels = $product
        ->get_saleable_item_quantity_details()
        ->{$channel_id};

    # Derviving these stock values is much slower than the others so we only
    # capture them when we really need them!
    my $extra_stock_levels;
    if ( defined $full_details ) {
        $extra_stock_levels = $product->get_ordered_item_quantity_details;

        if ($product->isa('XTracker::Schema::Result::Voucher::Product')
                and not $product->is_physical) {
            # let's lie a bit
            $extra_stock_levels->{$product->variant->id}
                ->{$VARIANT_TYPE__STOCK}->{total_ordered_quantity} ||= 1;
        }
    }

    my @variants = keys %$new_stock_levels;

    my $message = {
        channel_id => $channel_id,
        product_id => $product->id,
        variants => [],
    };
    for my $v (@variants) {
        # let's skip vendor samples
        my $slot = $new_stock_levels->{$v}{$VARIANT_TYPE__STOCK};
        next unless $slot;
        my $stock_sums;

        my %output_stock_levels;

        for my $name (keys %$slot) {
            $stock_sums += $slot->{$name};
            $output_stock_levels{$self->_public_name_for($name)}
                = $slot->{$name};
        }

        # munge in $extra_stock_levels
        if ( defined $full_details ) {
            my $extra_slot = $extra_stock_levels->{$v}{$VARIANT_TYPE__STOCK};
            for my $name (keys %$extra_slot) {
                $stock_sums += $slot->{$name}//0;
                $output_stock_levels{$name}=$extra_slot->{$name};
            }
            if ($output_stock_levels{total_ordered_quantity} == 0) {
                # let's check if it's really a zero
                if ($stock_sums > 0) {
                    # we have some kind of stock, "total ordered" can't
                    # really be zero: let's lie a bit
                    $output_stock_levels{total_ordered_quantity} = $stock_sums;
                }
                else {
                    my $quantity_records = $self->schema->
                        resultset('Public::Quantity')->count({
                            variant_id => $v,
                        });
                    if ($quantity_records > 0) {
                        # we have *had* some kind of stock, "total
                        # ordered" can't really be zero: let's lie a
                        # bit
                        $output_stock_levels{total_ordered_quantity} = 1;
                    }
                }
            }
        }

        push @{$message->{variants}}, {
            variant_id => $v,
            levels => \%output_stock_levels,
        };

        xt_logger()->debug(
            sprintf 'sending stock levels for variant %d product %d',
            $v,$product->id,
        );
    }
    $self->_add_to_messages($message);
}

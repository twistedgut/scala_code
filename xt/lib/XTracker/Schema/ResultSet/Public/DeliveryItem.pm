package XTracker::Schema::ResultSet::Public::DeliveryItem;
# vim: ts=4 sw=4:
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw/
    :delivery_item_status
/;

sub search_new_items {
    my ($self) = @_;

    my $me = $self->current_source_alias;
    $self->search_rs( { "$me.status_id" => $DELIVERY_ITEM_STATUS__NEW } )
}

sub prefetch_stock_order_items {
    my ($self) = @_;

    $self->search_rs( { }, {
        prefetch => { 'link_delivery_item__stock_order_items' => 'stock_order_item' },
    } )
}

sub prefetch_variants {
    my ($self) = @_;

    $self->search_rs( { }, {
        prefetch => [
            { 'link_delivery_item__stock_order_items' => {
                'stock_order_item' => { 'variant' => 'designer_size' },
            }, }
        ],
        order_by => 'variant.size_id'
    } )
}

=head2 uncancelled

Return a resultset with cancelled items.

=cut

sub uncancelled {
    my ( $self ) = @_;
    my $me = $self->current_source_alias;
    return $self->search({ "$me.cancel" => 0 });
}

=head2 distinct_deliveries

Returns a resultset of distinct delivery objects associated with
the current delivery_items

=cut
sub distinct_deliveries {
    my ($self) = @_;
    return $self->search_related('delivery', undef, { distinct => 1});
}

1;

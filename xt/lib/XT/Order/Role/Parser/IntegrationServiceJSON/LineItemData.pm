package XT::Order::Role::Parser::IntegrationServiceJSON::LineItemData;
use NAP::policy "tt", 'role';

sub _get_item_data {
    my ( $self, $node ) = @_;

    if (ref($node) ne 'ARRAY') {
        $node = [ $node ];
    }

    my $shipment_data = ();
    my $item_data = {};
    foreach my $shipment (@{$node}) {
        # process each normal item in the shipment
        foreach my $item (@{$shipment->{order_line}}) {
            # item id
            my $id = $item->{ol_id};
            $item_data->{ $id } = $self->_extract_common_item_data( $item );
        }

# FIXME: we currently don't deal with vouchers either physical/virtual
#        # process each physical voucher in the shipment
#        foreach my $item ( $shipment->findnodes('ORDER_LINE_PHYSICAL_VOUCHER') ) {
#            # item id
#            my $id = $item->findvalue('@OL_ID');
#
#            $item_data->{ $id } = $self->_extract_common_item_data( $item );
#            $item_data->{ $id }->{is_voucher} = 1;
#            $item_data->{ $id }->{is_gift} = 1;
#        }
#    }
#
#    foreach my $shipment ($node->findnodes('VIRTUAL_DELIVERY_DETAILS')) {
#        # process each virtual voucher in the shipment
#        foreach my $item ( $shipment->findnodes('ORDER_LINE_VIRTUAL_VOUCHER') ) {
#            # item id
#            my $id = $item->findvalue('@OL_ID');
#
#            $item_data->{ $id } = $self->_extract_common_item_data( $item );
#            $item_data->{ $id }->{is_voucher} = 1;
#            $item_data->{ $id }->{is_gift} = 1;
#        }
    }

    return $item_data;
}

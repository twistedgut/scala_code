package XT::Order::Role::Parser::NAPGroup::LineItemData;
use NAP::policy "tt", 'role';

requires 'as_list';

sub _get_item_data {
    my ( $self, $node ) = @_;

    $node = $self->as_list($node);

    my $shipment_data = ();
    my $item_data = {};

    foreach my $shipment (@{$node}) {
        # process each (normal) item in the shipment
        foreach my $item (@{$shipment->{order_lines}}) {
            my $id = $item->{ol_id}; # item id
            $item_data->{ $id } = $self->_extract_common_item_data( $item );

            # thanks to _fudge_voucher_data() in the DeliveryData role for
            # NAPgroup, virtual vouchers are 'in the right place' so we can
            # check for them in the normal order_lines
            if (exists $item->{voucher_type}) {
                given ($item->{voucher_type}) {
                    when ('VIRTUAL') {
                        $item_data->{ $id }->{is_voucher}   = 1;
                        $item_data->{ $id }->{is_gift}      = 1;
                    }

                    # TODO: when ('PHYSICAL') { ... }

                    default {
                        die   q{unknown voucher type '}
                            . $item->{voucher_type}
                            . q{' in order }
                            . $item->{ol_id}
                        ;
                    }
                }
            }
        }

        # process (physical) vouchers in the order
        #  we'd like to either extend _fudge_voucher_data or have the JSON
        #  format updated so that this lives with all the other order lines
        #  and we can process the physical voucher(s) in the foreach loop
        #  above here
        foreach my $item (@{$shipment->{order_line_voucher}}) {
            my $id = $item->{ol_id}; # item id
            $item_data->{ $id } = $self->_extract_common_item_data( $item );
            $item_data->{ $id }->{is_voucher}   = 1;
            $item_data->{ $id }->{is_gift}      = 1;
        }
    }

    return $item_data;
}

sub _extract_common_item_data {
    my $self = shift;
    my $item = shift;

    my %mapping = (
        'ol_id'        => 'sequence',
        'description'  => 'description',
        'sku'          => 'sku',
        'quantity'     => 'quantity',
        'gift_to'      => 'gift_to',
        'gift_from'    => 'gift_from',
        'gift_message' => 'gift_message',
        'returnable'   => 'returnable_state',
        'sale'         => 'sale',
    );
    my $out = $self->_extract(\%mapping,$item);
    $out->{sku} =~ s/\s+//g;
    $out->{unit_price} = $item->{unit_net_price}{amount} || 0;
    $out->{tax} = $item->{tax}{amount} || 0;
    $out->{duty} = $item->{duties}{amount} || 0;

    return wantarray ? %{$out} : $out;
}

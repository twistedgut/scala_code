package XT::Order::Role::Parser::NAPGroup::DeliveryData;
use NAP::policy "tt", 'role';
    with 'XT::Order::Role::Parser::NAPGroup::DataFudging';

use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;

requires 'is_parsable';
requires 'parse';
requires 'as_list';
requires '_fudge_address';

# until certain backlog tasks reach the top of the stack we're going to be
# getting voucher data through in strange places
# following on from a discussion we'd like vouchers to 'just be another order
# line'
# there's no reason we can't move the data to where we'd like it to be, and in
# the future our fox is just a case of removing this data shuffle
sub _fudge_voucher_data {
    my ($self, $order) = @_;
    my ($node);

    # move virtual vouchers into 'delivery_details'
    $node = $order->{virtual_delivery_details};
    my $additional_order_data = $self->as_list($node);
    my $additional_order_lines = [];

    # loop through the additional order lines make some tweaks to fit the
    # bigger picture
    foreach my $item (@{$additional_order_data}) {
        # order_line_voucher --> order_lines
        if (exists $item->{order_line_voucher}) {
            $item->{order_lines} = delete $item->{order_line_voucher};
        }
        # copy the recipient's email address into the order lines
        map
            { $_->{email} = $item->{email} }
                @{$item->{order_lines}};

        # push the munged order items onto our additional order lines
        push @{$additional_order_lines}, @{$item->{order_lines}};
    }

    # order_line_voucher is a list that lives in 'delivery_details'
    #   for now we'll leave this where it is and deal with this $elsewhere

    # make sure we're working with a list
    $node = $order->{delivery_details};
    my $delivery_details = $self->as_list($node);

    # add additional items item to the list of delivery items
    # - see comment below about "We don't handle multiple deliveries"
    # - so we will assume that it's always safe to add these items to the
    # first (and only) delivery_details item
    push @{ $delivery_details->[0]->{order_lines} }, @{$additional_order_lines};

    # replace the old delivery details with our munged version
    #   because of the way $delivery_details was created, it should already be
    #   in $order->{delivery_details} [reference magic] but I've left this
    #   here to be explicit about my intentions here
    $order->{delivery_details} = $delivery_details;

    return;
}

# in an ideal world we will have 'state' removed from the incoming data, and
# it'll either all go into 'county', or state/county/province will all be
# replaced by one coverall name (region? postalregion?)
sub _fudge_address_data {
    my ($self, $order) = @_;

    # usual comment about delivery_details only ever being a one item list and
    # we have bigger problems when this changes ...
    $self->_fudge_address( $order->{delivery_details}[0]{address} );
    $self->_fudge_address( $order->{billing_details}{address} );

    return;
}

sub _get_delivery_data {
    my ($self,$order) = @_;
    my ($shipments, $node);

    # when NAP/OUT work is completed we ought to be able to remove these
    # data-rearranging fudges
    $self->_fudge_voucher_data($order);
    $self->_fudge_address_data($order);

    $node = $order->{delivery_details};
    $shipments = $self->as_list($node);

    my $out = [];
    foreach my $del (@{$shipments}) {
        my $data = {
            name            => $self->_extract_name($del->{name}),
            address         => $self->_extract_address($del->{address}),
            gift_message    => $del->{gift_message},
        };
        # I don't know if gift_message and sticker (message) are the same
        # thing; I'm going to assume DIFFERENT so I don't put data where it
        # was never meant to go
        $data->{sticker} = $del->{sticker}
            if (exists $del->{sticker});
        push @{$out}, $data;

        # extra data to extract for flexi-ship (ORT-65)
        foreach my $field (qw[delivery_date dispatch_date]) {
            $data->{"nominated_${field}"} = $del->{$field}
                if exists $del->{$field};
        }
    }

    if (scalar @{$out} > 1) {
        die "We don't handle multiple deliveries - we'd have to change "
            ."the base method to deal with it which will break xml";
    }
    $out = shift @{$out};

    return $out;
}

1;

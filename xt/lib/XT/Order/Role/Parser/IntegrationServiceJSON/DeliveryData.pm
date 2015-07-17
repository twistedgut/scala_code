package XT::Order::Role::Parser::IntegrationServiceJSON::DeliveryData;
use NAP::policy "tt", 'role';

use XT::Data::Types;
use DateTime::Format::Strptime;
use Data::Dump qw/pp/;

requires 'is_parsable';
requires 'parse';

sub _get_delivery_data {
    my($self,$order) = @_;
    my $shipments;
    my $node = $order->{delivery_details};

    if (defined $node && ref($node) ne 'ARRAY') {
        $shipments = [ $node ];
    } else {
        $shipments = $node;
    }

    my $out = [];
    foreach my $del (@{$shipments}) {
        my $data = {
            name            => $self->_extract_name($del->{name}),
            address         => $self->_extract_address($del->{address}),
            gift_message    => $del->{gift_message},
        };
        push @{$out}, $data;
    }

    if (scalar @{$out} > 1) {
        die "We don't handle multiple deliveries - we'd have to change "
            ."the base method to deal with it which will break xml";
    }
    $out = shift @{$out};

    return $out;
}

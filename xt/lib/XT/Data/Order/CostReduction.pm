package XT::Data::Order::CostReduction;

use Moose;
use namespace::autoclean;

use XT::Data::Types;

has id => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has type => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);


has description => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

# value: is the total amount removed from this LineItem -
# the quantity of this line-item is factored in.
has value => (
    is          => 'rw',
    isa         => 'Num',
    required    => 1,
);


# unit_price: is the amount removed from the unit price for *one*
# of these items
has unit_net_price => (
    is          => 'rw',
    isa         => 'Num',
    required    => 1,
    default     => 0,
);

# tax: is the amount removed from the tax price for *one*
# of these items
has unit_tax => (
    is          => 'rw',
    isa         => 'Num',
    required    => 1,
    default     => 0,
);

# duty: is the amount removed from the duty price for *one*
# of these items
has unit_duties => (
    is          => 'rw',
    isa         => 'Num',
    required    => 1,
    default     => 0,
);

sub total {
    my $self = shift;

    return $self->unit_net_price + $self->unit_tax + $self->unit_duties;
}


__PACKAGE__->meta->make_immutable;

1;


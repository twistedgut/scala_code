package XT::Data::Order::Promotion;

use Moose;
use namespace::autoclean;

use XT::Data::Types;

=head1 NAME

XT::Data::Order::Promotion - A promotion for an order for fulfilment

=head1 DESCRIPTION

This class represents a promotion for an order that is to be inserted into
XT's order database.

=head1 ATTRIBUTES

=head2 id

=cut

has id => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

=head2 type

=cut

has type => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 description

=cut

has description => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 value

Attribute is of class L<XT::Data::Money>.

=cut

has value => (
    is          => 'rw',
    isa         => 'XT::Data::Money',
    required    => 1,
);

=head1 SEE ALSO

L<XT::Data::Order>,
L<XT::Data::Order::LineItem>

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;


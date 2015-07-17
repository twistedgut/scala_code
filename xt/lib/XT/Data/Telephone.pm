package XT::Data::Telephone;

use Moose;
use namespace::autoclean;

=head1 NAME

XT::Data::Telephone - A telephone number

=head1 DESCRIPTION

This class represents a telephone number

=head1 ATTRIBUTES

=head2 type

=cut

# FIXME enum? what are the types?
has type => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head1 number

=cut

has number => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;

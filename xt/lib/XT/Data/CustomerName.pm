package XT::Data::CustomerName;

use Moose;
use namespace::autoclean;

=head1 NAME

XT::Data::CustomerName - A customer name

=head1 DESCRIPTION

This class represents the name of a customer

=head1 ATTRIBUTES

=head2 title

=cut

has title => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 last_name

=cut

has first_name => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 first_name

=cut

has last_name => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;


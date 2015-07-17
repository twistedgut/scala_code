package XT::Data::Customer;

use NAP::policy "tt", 'class';
use Moose::Util::TypeConstraints;

use XT::Data::URI;
use XT::Data::Types qw/ TimeStamp URN /;

=head1 NAME

XT::Data::Customer - A customer

=head1 DESCRIPTION

This class represents a customer

=head1 TYPES

=cut

=head1 ATTRIBUTES

=head2 urn

=cut

has urn => (
    is       => 'ro',
    isa      => 'XT::Data::Types::URN',
    required => 0,
    coerce   => 1,
);

=head2 last_modified

=cut

has last_modified => (
    is       => 'ro',
    isa      => 'XT::Data::Types::TimeStamp',
    required => 0,
    coerce   => 1,
);

=head2 accounts

=cut

has accounts => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 0,
);

=head1 METHODS

=head2 as_dbi_like_hash

Returns a hash of the object data suitable for drop-in replacement of
DBI-based address hash data

=cut

sub as_dbi_like_hash {
    my $self = shift;
    my $customer_data = { urn           => $self->urn,
                          last_modified => $self->last_modified,
                        };

    return $customer_data;
}

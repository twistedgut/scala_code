package XT::Data::Address;

use Moose;
use Moose::Util::TypeConstraints;
extends 'XT::Data';

use XT::Data::Types qw/ TimeStamp URN /;

use namespace::autoclean;

=head1 NAME

XT::Data::Address - An address

=head1 DESCRIPTION

This class represents an address

=head1 ATTRIBUTES

=head2 schema

=cut

with 'XTracker::Role::WithSchema';

=head2 urn

=cut

has urn => (
    is       => 'rw',
    isa      => 'XT::Data::Types::URN|Undef',
    required => 0,
    coerce   => 1,
);

=head2 last_modified

=cut

has last_modified => (
    is       => 'rw',
    isa      => 'XT::Data::Types::TimeStamp|Undef',
    required => 0,
    coerce   => 1,
);

=head2 account_urn

=cut

has account_urn => (
    is       => 'rw',
    isa      => 'XT::Data::Types::URN | Undef',
    required => 0,
    coerce   => 1,
);

=head2 address_type

=cut

has address_type => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);

=head2 title

=cut

has title => (
    is          => 'rw',
    isa         => 'Any',
    required    => 0,
);

=head2 first_name

=cut

has first_name => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 last_name

=cut

has last_name => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 line_1

=cut

has line_1 => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 line_2

=cut

has line_2 => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 line_3

=cut

has line_3 => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 town

=cut

has town => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 county

=cut

has county => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 state

=cut

has state => (
    is          => 'rw',
    isa         => 'Str',
    required    => 0,
);

=head2 postcode

=cut

has postcode => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 country

=cut

has country_code => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 clone

Returns a clone of this object

=cut

sub clone {
    my ($self, %params) = @_;
    return $self->meta->clone_object($self, %params);
}

=head2 country

=cut

sub country {
    my ( $self ) = @_;

    my $country_rs = $self->schema->resultset('Public::Country');
    my $country = $country_rs->find({ code => $self->country_code });

    return $country;
}

=head2 as_dbi_like_hash

Returns a hash of the object data suitable for drop-in replacement of
DBI-based address hash data

=cut

sub as_dbi_like_hash {
    my $self = shift;
    my $address_data = {};

    $address_data->{urn}            = $self->urn;
    $address_data->{last_modified}  = $self->last_modified;
    $address_data->{address_type}   = $self->address_type;
    $address_data->{title}          = $self->title;
    $address_data->{first_name}     = $self->first_name;
    $address_data->{last_name}      = $self->last_name;
    $address_data->{address_line_1} = $self->line_1;
    $address_data->{address_line_2} = $self->line_2;
    $address_data->{address_line_3} = $self->line_3;
    $address_data->{towncity}       = $self->town;
    $address_data->{postcode}       = $self->postcode;
    $address_data->{county}         = $self->county;
    $address_data->{state}          = $self->state;
    if($self->country){
        $address_data->{country} = $self->country->country;
    }

    return $address_data;
}

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;

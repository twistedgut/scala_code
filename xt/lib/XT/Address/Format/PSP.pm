package XT::Address::Format::PSP;
use NAP::policy 'class';

extends 'XT::Address::Format';

=head1 NAME

XT::Address::Format::PSP

=head1 DESCRIPTION

Formats an address to be suitable for the PSP.

=cut

sub APPLY_FORMAT {
    my $self = shift;

    # Explicitly set the address data.
    $self->address->address_data({
        address1        => $self->get_field('address_line_1'),
        streetName      => $self->get_field('street_name'),
        houseNumber     => $self->get_field('house_number'),
        address2        => $self->get_field('address_line_2'),
        city            => $self->get_field('towncity'),
        stateOrProvince => $self->get_field('county'),
        postcode        => $self->get_field('postcode'),
        country         => $self->address->lookup_country_code_by_country,
    });

}

=head1 METHODS

=head2 get_field( $field )

Returns the value of the address C<$field> or an empty string if the field is
undefined.

=cut

sub get_field {
    my $self = shift;
    my ( $field ) = @_;

    return $self->address->get_field( $field ) // '';

}

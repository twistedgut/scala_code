package XT::Address;
use NAP::policy 'class';

=head1 NAME

XT::Address

=head1 DESCRIPTION

A representation of an address that can have formatting applied using
various plugins.

A plugin takes the following form:

    package XT::Address::Format::MyFormat;
    use NAP::policy 'class';

    sub APPLY_FORMAT {
        my $self = shift;
        my ( $address ) = @_;

        # Do something to $address, by using any of it's
        # methods, for example:

        $address->add_field( field_name => 'Field Value' );
        $address->set_field( existing_field_name => 'New Value' );
        $address->remove_field( 'another_field_name' );

    }

=head1 SYNOPSIS

    my $address = $schema->resultset('Public::OrderAddress')->find( $id );

    my $xt_address = XT::Address->new( $address );
    # .. or ..
    my $xt_address = XT::Address->new({ original => $address });

    $xt_address
        ->apply_format('FormatOne')
        ->apply_format('FormatTwo');

    use DDP;
    print p( $xt_address->as_hash );

=cut

use Class::Load 'try_load_class';
use XTracker::Utilities 'trim';

=head1 ATTRIBUTES

=head2 original

A required attribute of type L<XTracker::Schema::Result::Public::OrderAddress>.

This is the orignal address record, which DOES NOT get updated or altered in
any way.

=cut

has original => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::OrderAddress',
    required    => 1,
);

=head2 schema

A reference to the L<XTracker::Schema> object attached to the C<original>
address.

=cut

has schema => (
    is      => 'ro',
    isa     => 'XTracker::Schema',
    lazy    => 1,
    default => sub { shift->original->result_source->schema },
);

=head2 trim_fields

If set to TRUE (default value) all the address fields will be trimmed by
default at instantiation ONLY. Set this attribute to FALSE to leave all the
address fields as they are.

=cut

has trim_fields => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

=head2 address_data

A HashRef storing the representation of the current address data. This can
also be used in plugins if required.

=head1 METHODS

=head2 add_field( $field_name, $field_value )

Adds the field C<$field_name> with the value C<$field_value> to the address.

    $xt_address->add_field( field_name => 'Field Value' );

=head2 set_field( $field_name, $field_value )

Updates the address field C<$field_name> to have the value C<$field_value>.

    $xt_address->set_field( field_name => 'Field Value' );

=head2 get_field( $field_name )

Returns the value of the address field C<$field_name>.

    $xt_address->get_field( 'field_name' );

=head2 remove_field( $field_name )

Removes the address field C<$field_name>.

    $xt_address->remove_field( 'field_name' );

=head2 as_hash

Returns the address as a Hash (not a HashRef).

    my %address_hash = $xt_address->as_hash;

=head2 field_exists( $field_name )

Returns TRUE or FALSE depending on whether or not the field C<$field_name>
exists.

    print $xt_address->field_exists('field_name')
        ? 'Yes'
        : 'No';

=cut

has address_data => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
    traits  =>  ['Hash'],
    handles => {
        add_field               => 'set',
        set_field               => 'set',
        get_field               => 'get',
        remove_field            => 'delete',
        as_hash                 => 'elements',
        field_exists            => 'exists',
    },
);

around BUILDARGS => sub {
    my $original    = shift;
    my $class       = shift;

    if ( @_ == 1 && ref( $_[0] ) ne 'HASH' ) {
        return $class->$original({
            original => $_[0],
        });
    } else {
        return $class->$original( @_ );
    }

};

sub BUILD {
    my $self = shift;

    foreach my $column_name ( $self->original->result_source->columns ) {

        my $value = $self->trim_fields
            ? trim( $self->original->$column_name )
            : $self->original->$column_name;

        $self->add_field( $column_name => $value );

    }

}

=head2 apply_format( $format )

Applies the specified C<$format> to the address.

    $xt_address->apply_format('MyFormat');

This method is chainable, so the following can also be used:

    $xt_address
        ->apply_format('MyFormat')
        ->apply_format('AnotherFormat');

=cut

sub apply_format {
    my $self = shift;
    my ( $format ) = @_;

    my $class = ref( $self ) . '::Format::' . $format;

    if ( try_load_class( $class ) ) {
        my $formatter = $class->new({ address => $self });

        if ( $formatter->can('APPLY_FORMAT') ) {
            $formatter->APPLY_FORMAT;
        } else {
            warn("Format '$format' is not a valid formatter");
        }
    } else {
        warn("Format '$format' does not exist");
    }

    # Make it chainable.
    return $self;

}

=head2 as_hashref

Return the address as a HashRef. This is just a convenience method with a
more descriptive name.

=cut

sub as_hashref {
    my $self = shift;

    return { $self->as_hash };

}

=head2 lookup_country_code_by_country( $country_field )

A helper method to be used in plugins, that takes the value from a given
C<$country_field>, looks that up in the public.country table and returns the
associated country code.

If C<$country_field> is not provided it defaults to 'country'.

    # Using the 'country' field.
    $xt_address->lookup_country_code_by_country;

    # Using a specific field.
    $xt_address->lookup_country_code_by_country('country_name');

=cut

sub lookup_country_code_by_country {
    my $self = shift;
    my ( $country_field ) = @_;

    my $country_name    = $self->get_field( $country_field // 'country' );
    my $country         = $self->schema->resultset('Public::Country')
        ->search({ country => { ilike => $country_name } })
        ->slice(0,0)
        ->single;

    return defined $country
        ? $country->code
        : '';

}

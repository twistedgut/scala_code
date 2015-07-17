package XT::Net::Seaview::Role::Representation::JSON;

use NAP::policy "tt", 'role';
use JSON;

=head1 NAME

XT::Net::Seaview::Role::Representation::JSON

=head1 DESCRIPTION

JSON

=head1 ATTRIBUTES

=head2 identity

Resource identity for JSON representations is the value of the "id" field

=cut

sub _build_identity {
    return shift->data->{'id'};
}

=head2 media_type

This representation's media type

=cut

sub media_type {
    return 'application/json';
}

=head2 data

Build HashRef of account data from a source. This can be either an XT::Data
object or a JSON string.

=cut

has data => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_data',
);

sub _build_data {
    my $self = shift;
    my $data = undef;

    if ( ref( $self->src ) eq 'HASH' ) {
        $data = $self->src;
    }
    elsif ( $self->src->isa('XT::Data') ) {
        # Hashref from an XT::Data Object
        $data = { map { $self->serialised_fields->{$_} => $self->src->$_ }
                      keys %{$self->serialised_fields} };
    }
    else {
        # Hashref from a JSON string
        $data = JSON->new->utf8->convert_blessed->decode($self->src);
    }

    return $data;
}

=head1 METHODS

=head2 convert_booleans

For this instance, convert boolean attribute values from stringified "1" and
"0" to a values that Seaview understands as true and false

=cut

sub convert_booleans {
    my ($self, $data) = @_;

    # Moose Bools appear to be serialised as strings of either '1' or
    # '0'. Huh? Convert these to something Seaview understands as boolean true
    # and false
    foreach my $attr ($self->data_obj_class->meta->get_all_attributes){
        if(defined $attr->type_constraint
             && $attr->type_constraint eq 'XT::Data::Types::ResourceBool'){
            $data->{$self->serialised_fields->{$attr->name}}
              = $data->{$self->serialised_fields->{$attr->name}} ? JSON::true : JSON::false;
        }
    }

    return $data;
}

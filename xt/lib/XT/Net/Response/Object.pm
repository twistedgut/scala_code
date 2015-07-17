package XT::Net::Response::Object;
use NAP::policy "tt", "class";

=head1 NAME

XT::Net::Response::Object - Base class for Values object e.g. returned by calls to the WebsiteAPI

=cut

=head2 as_data() : $data_structure

Return the object's attributes as a data structure without any
objects, suitable for serialising into JSON. By default, objects are
stringified.

Note: currently only top level objects are stringified, nested objects
will need work.

=cut

sub as_data {
    my $self = shift;
    return {
        map {
            my $attribute_name = $_;
            my $value = $self->$attribute_name;

            # Stringify objects, they better have overloaded
            # stringification.
            # Pass everything else through.
            $value = "$value" if(blessed($value));

            ( $attribute_name => $value );
        }
        # Ignore the hashref { name => subref } form, see
        # http://search.cpan.org/dist/Moose/lib/Class/MOP/Attribute.pm
        map { $_->accessor || $_->reader }
        $self->meta->get_all_attributes()
    };
}

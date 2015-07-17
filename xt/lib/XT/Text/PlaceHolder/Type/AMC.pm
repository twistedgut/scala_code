package XT::Text::PlaceHolder::Type::AMC;
use NAP::policy 'class';

extends 'XT::Text::PlaceHolder::Type';

use MooseX::Types::Moose qw(
    Str
    ArrayRef
    RegexpRef
);

=head1 XT::Text::PlaceHolder::Type::AMC

Advanced Method Call Place Holder.

    P[AMC.Class::Name.method_to_call(parameter,...)]

At present parameters are just a comma seperated list of un-quoted
values and cannot accept complex structures. For example, these are
all valid:

    P[AMC.Class::Name.method_to_call(1)]
    P[AMC.Class::Name.method_to_call(1,2)]
    P[AMC.Class::Name.method_to_call(some string)]
    P[AMC.Class::Name.method_to_call(some string,another string)]

This is valid, however the single quotes would be included in the
parameter:

    P[AMC.Class::Name.method_to_call('some string')]
    P[AMC.Class::Name.method_to_call('some string','another string')]

=cut

use JSON;

=head1 ATTRIBUTES

=cut

=head2 objects

Objects is required for this Place Holder.

=cut

has '+objects' => (
    required    => 1,
);

=head2 part1_split_pattern

Used to get the Class Name to call the Method on.

=cut

has part1_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/(?<_class_name>^.*\w+::\w+.*$)/;
    },
);

=head2 part2_split_pattern

Used to get the Method to call on the Class.

=cut

has part2_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/(?<_method_name>^\w+)\((?<_parameter_string>.+)\)$/;
    },
);

#
# These will be populated when the Parts get split up by the
# Parent method: '_split_up_parts' at the point of instantiation
#

has _class_name => (
    is      => 'rw',
    isa     => Str,
);

has _method_name => (
    is      => 'rw',
    isa     => Str,
);

has _parameter_string => (
    is      => 'rw',
    isa     => Str,
    trigger => \&_split_parameters
);

sub _split_parameters {
    my $self = shift;

    $self->_parameters( [ split /,/, $self->_parameter_string ] );

}

#
# This will be populated automatically when _parameter_string is
# set.
#

has _parameters => (
    is      => 'rw',
    isa     => ArrayRef,
    traits  => ['Array'],
    handles => {
        all_parameters => 'elements',
    },
);

=head1 METHODS

=head2 value

    $scalar = $self->value;

Will get the Value, encoded as JSON, for the Place Holder from the Method Call.

=cut

sub value {
    my $self = shift;

    my $class_name  = $self->_class_name;
    my $method_name = $self->_method_name;
    my @parameters  = $self->all_parameters;

    my ( $object ) = grep { ref( $_ ) =~ /${class_name}$/ } $self->all_objects;

    unless ( $object ) {
        $self->_log_croak( "Class requested is not in object list: '${class_name}'" );
    }

    unless ( $object->can( $method_name ) ) {
        $self->_log_croak( "Method requested is not on Class: ${class_name}->${method_name}" );
    }

    # Encode the results of the method call.
    my $encoded_result = JSON->new
        # Make sure objects don't barf and instead use the TO_JSON method
        # if available, or return 'null' if not.
        ->allow_blessed
        # This allows us to encode individual scalar results.
        ->allow_nonref
        # Wrap the results of the method call in an ArrayRef.
        ->encode( [ $object->$method_name( @parameters ) ] );

    return $self->_check_value( $encoded_result );

}

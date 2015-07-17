package XT::Text::PlaceHolder::Type::SMC;

use NAP::policy "tt",     'class';
extends 'XT::Text::PlaceHolder::Type';

=head1 XT::Text::PlaceHolder::Type::SMC

Simple Method Call Place Holder.

    P[SMC.Class::Name.method_to_call]

=cut

use MooseX::Types::Moose qw(
    Str
    Object
    ArrayRef
    RegexpRef
);


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
        return qr/(?<_method_name>^\w+.*$)/;
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

=head1 METHODS

=head2 value

    $scalar = $self->value;

Will get the Value for the Place Holder from the Method Call.

=cut

sub value {
    my $self    = shift;

    my $class_name  = $self->_class_name;
    my $method_name = $self->_method_name;

    my ( $object )  = grep { ref( $_ ) =~ /${class_name}$/ } $self->all_objects;

    if ( !$object ) {
        $self->_log_croak( "Class requested is not in object list: '${class_name}'" );
    }
    if ( !$object->can( $method_name ) ) {
        $self->_log_croak( "Method requested is not on Class: ${class_name}->${method_name}" );
    }

    return $self->_check_value( $object->$method_name );
}


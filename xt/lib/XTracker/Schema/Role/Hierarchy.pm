package XTracker::Schema::Role::Hierarchy;
use NAP::policy "tt", 'role';

use Carp;

use XTracker::Database::SchemaHierarchy     qw(
                                                get_hierarchy_definition
                                                get_hierarchy_name
                                                class_higher_or_same
                                            );
use XTracker::Utilities                     qw(
                                                get_class_suffix
                                                class_suffix_matches
                                            );

=head1 XTracker::Schema::Role::Hierarchy

A role for getting the next record in a Hierarchy defined in 'XTracker::Database::SchemaHierarchy'

Currently a Role for:
    * Public::Customer
    * Public::Orders
    * Public::Reservation
    * Public::Shipment
    * Public::Return
    * Public::Renumeration


Currently using the 'Customer' hierarchy.

=cut

=head2 next_in_hierarchy

    $rec_obj    = $self->next_in_hierarchy;
                    or
    $rec_obj    = $self->next_in_hierarchy( $hierarchy_name );

Returns the next record in a Hierarchy.

$hierarchy_name specifies the hierarchy to use, it is optional and if omitted the Class
of $self will be used to find a Hierarchy that it is in, if however it turns out to exist
in more than one Hierarchy and error will be thrown.

=cut

sub next_in_hierarchy {
    my ( $self, $hierarchy_name )   = @_;

    my $definition  = get_hierarchy_definition( $hierarchy_name || $self );

    my $parent;
    if ( my $sub = $definition->{traverse_hierarchy}{ get_class_suffix( $self ) } ) {
        $parent = $sub->( $self );
    }

    return $parent;
}

=head2 next_in_hierarchy_isa

    $boolean    = $self->next_in_hierarchy_isa( $class );
                    or
    $boolean    = $self->next_in_hierarchy_isa( $hierarchy_name, $class );

Returns TRUE or FALSE if the next record in the Hierarchy is a certain Class.

$hierarchy_name specifies the hierarchy to use, it is optional and if omitted the Class
of $self will be used to find a Hierarchy that it is in, if however it turns out to exist
in more than one Hierarchy and error will be thrown.

=cut

sub next_in_hierarchy_isa {
    my ( $self, @params )   = @_;

    my $class   = pop @params;
    if ( !$class ) {
        croak "No Class Name passed in to '" . __PACKAGE__ . "::next_in_hierarchy_isa'";
    }

    my $hierarchy_name;
    $hierarchy_name = $params[0]    if ( @params );
    $hierarchy_name ||= get_hierarchy_name( $self );

    my $result  = 0;
    if ( my $next = $self->next_in_hierarchy( $hierarchy_name ) ) {
        $result = 1         if ( class_suffix_matches( $next, $class ) );
    }

    return $result;
}

=head2 next_in_hierarchy_from_class

    $rec_obj    = $self->next_in_hierarchy_from_class( $class, { # optional
                                                                stop_if_me  => 1,
                                                            } );
                    or
    $rec_obj    = $self->next_in_hierarchy_from_class( $hierarchy_name, $class, { ... } );

Returns the next record in the Hierarchy starting from a Class, allows you to skip over other Classes
if you don't wish to take them into account.

If $self equals $class or is a Class past $class in the hierarchy then it will get the next Class in the Hierarchy,
otherwise if it is lower than $class in the Hierarchy it will STOP when it reaches $class. Pass in 'stop_if_me' if
you want it to stop immediately if $self equals $class.

Will return 'undef' if no Class found.

$hierarchy_name specifies the hierarchy to use, it is optional and if omitted the Class
of $self will be used to find a Hierarchy that it is in, if however it turns out to exist
in more than one Hierarchy an error will be thrown.

=cut

sub next_in_hierarchy_from_class {
    my ( $self, @params )   = @_;

    my ( $hierarchy_name, $class, $args )   = $self->_unpack_three_params_for_hierarchy( @params );
    $hierarchy_name ||= get_hierarchy_name( $self );

    if ( !$class ) {
        croak "No Class Name passed in to '" . __PACKAGE__ . "::next_in_hierarchy_from_class'";
    }
    if ( $args && ref( $args ) ne 'HASH' ) {
        croak "Arguments is not a Hash Ref passed in to '" . __PACKAGE__ . "::next_in_hierarchy_from_class'";
    }
    my $stop_if_me  = $args->{stop_if_me} || 0;

    # if 'stop_if_me' has been passed in then, if $self is for $class then return $self
    return $self    if ( $stop_if_me && class_suffix_matches( $self, $class ) );

    my $rec;
    if ( $rec = $self->next_in_hierarchy( $hierarchy_name ) ) {
        return $rec     if ( class_suffix_matches( $rec, $class ) || class_higher_or_same( $hierarchy_name, $rec, $class ) );
        $rec    = $rec->next_in_hierarchy_from_class( $hierarchy_name, $class );
    }

    return $rec;
}

=head2 next_in_hierarchy_with_method

    $rec_obj    = $self->next_in_hierarchy_with_method( $method, { # optional
                                                                stop_if_me => 1,
                                                                from_class => $class,
                                                            } );
                    or
    $rec_obj    = $self->next_in_hierarchy_with_method( $hierarchy_name, $method, { ... } );

Returns the next record in the Hierarchy that has a particular Method.

Pass in 'stop_if_me' if $self should be queried first. Use 'from_class' to show which Class
to start from before checking for the Method, if used with 'stop_if_me' will check $self first
regardless of its Class. If $self's Class is lower than 'from_class' in the Hierarchy then it
will check record that matches 'from_class' to see if it has the Method but if $self is the
same or greater than 'from_class' in the Hierarchy then it will get the next record and check
that for the Method.

Will return 'undef' if no Method found.

$hierarchy_name specifies the hierarchy to use, it is optional and if omitted the Class
of $self will be used to find a Hierarchy that it is in, if however it turns out to exist
in more than one Hierarchy and error will be thrown.

=cut

sub next_in_hierarchy_with_method {
    my ( $self, @params )   = @_;

    my ( $hierarchy_name, $method, $args )  = $self->_unpack_three_params_for_hierarchy( @params );
    $hierarchy_name ||= get_hierarchy_name( $self );

    if ( !$method ) {
        croak "No Method Name passed in to '" . __PACKAGE__ . "::next_in_hierarchy_with_method'";
    }
    if ( $args && ref( $args ) ne 'HASH' ) {
        croak "Arguments is not a Hash Ref passed in to '" . __PACKAGE__ . "::next_in_hierarchy_with_method'";
    }

    my $from_class  = $args->{from_class} || "";
    my $stop_if_me  = $args->{stop_if_me} || 0;

    if ( $stop_if_me ) {
        return $self    if ( $self->can( $method ) );
    }

    my $rec = $self;
    # if been asked to start from a Class, jump there and check it first
    # unless $self is already that class or higher in the Hierarchy
    if ( $from_class && !class_higher_or_same( $hierarchy_name, $self, $from_class ) ) {
        $rec    = $self->next_in_hierarchy_from_class( $hierarchy_name, $from_class );
        return          if ( !$rec );       # can't find a rec with that Class
        return $rec     if ( $rec->can( $method ) );
    }

    if ( $rec = $rec->next_in_hierarchy( $hierarchy_name ) ) {
        return $rec     if ( $rec->can( $method ) );
        $rec    = $rec->next_in_hierarchy_with_method( $hierarchy_name, $method );
    }

    return $rec;
}

# used to work out what is what in parameters passed into
# next_in_hierarchy_from_class & next_in_hierarchy_with_method
sub _unpack_three_params_for_hierarchy {
    my ( $self, @params )   = @_;

    # 0 - Hierarchy Name, 1 - Param, 2 - Arguments
    my @retval;

    if ( @params == 3 ) {
        @retval = @params;
    }
    elsif ( @params == 2 ) {
        if ( ref( $params[-1] ) ) {
            $retval[1]  = $params[0];
            $retval[2]  = $params[1];
        }
        else {
            @retval = @params;
        }
    }
    else {
        $retval[1]  = $params[0];
    }

    return @retval;
}

1;

package XTracker::Database::SchemaHierarchy;

use NAP::policy "tt",     'exporter';

use Perl6::Export::Attrs;

use XTracker::Utilities         qw(
                                    get_class_suffix
                                    class_suffix_matches
                                );


=head1 XTracker::Database::SchemaHierarchy

This defines various Database Hierarchies used throughout the System. Will use Classes as defined through DBIC.

=head1 HIERARCHIES

=head2 Customer Hierarchy

Below describes the Customer Hierarchy of DBIC Classes with their Levels (LV) next to them:

                            Customer (LV 0)
                               |
                      ________/ \_____________________________
                     /                      |                 \
                  Orders (LV 1)      Reservation (LV 1)    PreOrder (LV 1)
                    |
                 Shipment (LV 2)
                    |
                   / \______
                  /         \
               Return (LV 3) |
                  \____   __/
                       \ /
                        |
                   Renumeration (LV 3 or 4)

Because 'Renumeration' can be either for a Shipment or a Return, it is considered to be at Level 3
unless it is for a Return then it will be a Level 4, but it's default Level is 3.

=cut

# this defines the hierarchies used
my %_hierarchies = (
    'Customer'  => {
        hierarchy   => {
                Customer        => sub { return 0; },
                Reservation     => sub { return 1; },
                PreOrder        => sub { return 1; },
                Orders          => sub { return 1; },
                Shipment        => sub { return 2; },
                Return          => sub { return 3; },
                Renumeration    => sub {
                            my $rec = shift;
                            if ( $rec && $rec->return ) {
                                return 4;
                            }
                            else {
                                return 3;   # default to level 3
                            }
                        },
            },
        traverse_hierarchy => {
                Customer        => sub { return; },
                Reservation     => sub { my $rec = shift; return $rec->customer; },
                PreOrder        => sub { my $rec = shift; return $rec->customer; },
                Orders          => sub { my $rec = shift; return $rec->customer; },
                Shipment        => sub { my $rec = shift; return $rec->order; },
                Return          => sub { my $rec = shift; return $rec->shipment; },
                Renumeration    => sub { my $rec = shift; return $rec->return || $rec->shipment; },
            },
        },
);

=head1 METHODS

=head2 get_hierarchy_definition

    $hash_ref   = get_hierarchy_definition( $record or $hierarchy_key );

This will return the Hierarchy Definition for a given $hierarchy_key that is defined in the '%_hierarchies' hash.

If you pass in a DBIC Record it will then get the Class Suffix and search through the '%_hierarchies' definitions
until it finds a match for the record's Class. If it finds more that One Class it will Throw an error.

'undef' will be returned if it can't find anything.

=cut

sub get_hierarchy_definition :Export {
    my $hierarchy   = shift;

    return      if ( !$hierarchy );

    my $hierarchy_name  = $hierarchy;       # assume a string
    if ( ref( $hierarchy ) ) {
        # $hierarchy a DBIC record
        $hierarchy_name = get_hierarchy_name( $hierarchy );
    }

    my $definition;
    $definition = $_hierarchies{ $hierarchy_name }       if ( exists( $_hierarchies{ $hierarchy_name } ) );

    return $definition;
}

=head2 get_hierarchy_name

    $string = get_hierarchy_name( $record or $class_name );

Will find the the Hierarchy Name that the $record or $class_name is part of in the '%_hierarchies' hash.

If you pass in a DBIC Record it will then get the Class and search through the '%_hierarchies' definitions
until it finds a match for the record's Class. If it finds more that One Class it will Throw an error.

'undef' will be returned if it can't find anything.

=cut

sub get_hierarchy_name :Export {
    my $class   = shift;

    my $hierarchy_name;

    my @names   = get_hierarchy_names_for_class( $class );
    if ( @names ) {
        if ( @names > 1 ) {
            croak "Found " . @names . " definitions for the Class '$class' in '" . __PACKAGE__ . "::get_hierarchy_name'";
        }
        $hierarchy_name = $names[0];
    }

    return $hierarchy_name;
}

=head2 get_hierarchy_names_for_class

    @array      = get_hierarchy_name( $class_name );
    $array_ref  = get_hierarchy_name( $class_name );

Will return all the names of the Hierarchies that $class_name is in, in an Array or Array Ref depending on context.

Will return empty if no Hierarchies are found.

=cut

sub get_hierarchy_names_for_class :Export {
    my $class_name  = get_class_suffix( shift );

    my @names;
    if ( $class_name ) {
        foreach my $name ( keys %_hierarchies ) {
            if ( grep { $_ eq $class_name } keys %{ $_hierarchies{ $name }{hierarchy} } ) {
                push @names, $name;
            }
        }
    }

    return ( wantarray ? @names : \@names );
}

=head2 class_higher_or_same

    $boolean    = class_higher_or_same( $hierarchy, $record, $class_name );

Returns TRUE if $record's Class is $class or higher than $class in its hierarchy.

=cut

sub class_higher_or_same :Export {
    my ( $hierarchy, $rec, $class )     = @_;

    if ( !$hierarchy ) {
        croak "No Hierarchy Name passed in to '" . __PACKAGE__ . "::class_higher_or_same'";
    }

    return 0        if ( !$rec || !$class || !exists( $_hierarchies{ $hierarchy } ) );

    my $rec_pos     = $_hierarchies{ $hierarchy }{hierarchy}{ get_class_suffix( $rec ) };
    my $class_pos   = $_hierarchies{ $hierarchy }{hierarchy}{ get_class_suffix( $class ) };

    # dunno the Classes
    return 0        if ( !defined $rec_pos || !defined $class_pos );

    return ( $rec_pos->( $rec ) <= $class_pos->() ? 1 : 0 );
}


1;

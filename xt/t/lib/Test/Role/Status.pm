package Test::Role::Status;

use NAP::policy "tt",     qw( test role );

requires 'get_schema';

=head1 NAME

Test::Role::Status - a Moose role to do Status Related Stuff

=head1 SYNOPSIS

    package Test::Foo;

    with 'Test::Role::Status';

    __PACKAGE__->get_allowed_notallowed_statuses( 'Public::ShipmentStatus', { allow => [ $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__DISPATCHED ] } );

=cut

=head1 METHODS

=head2 get_allowed_notallowed_statuses

    $hash_ref   = __PACKAGE__->get_allowed_notallowed_statuses( 'Public::StatusClass', {
                                                                        # one of the following:
                                                                        allow => [
                                                                                Array of ALLOWED Status Ids
                                                                            ],
                                                                                or
                                                                        not_allow => [
                                                                                Array of NOT allowed Status Ids
                                                                            ],
                                                                        # and optionally:
                                                                        exclude => [
                                                                                Array of Statuses to ignore and NOT return
                                                                            ],
                                                                    } );

If you have a Method that should only work with records of some statuses and not work with other statuses then you
can use this method to return you a list of the the Allowed Statuses and the corresponding NOT Allowed Statuses so
you can use these in your tests to check the functionality.

Pass in the Class of the Status Record and then either a list of the Allowed Status Ids or of the NOT Allowed Status Ids
depending on which is the most appropriate angle to get the Statuses.

returns:
    {
        allowed     => [ Array Ref of Status Objects ],
        not_allowed => [ Array Ref of Status Objects ],
    }

=cut

sub get_allowed_notallowed_statuses {
    my ( $self, $class, $args )     = @_;

    if ( $args->{allow} && $args->{not_allow} ) {
        croak "Can't specify both 'allow' & 'not_allow' arguments only use ONE of them";
    }

    my $schema  = $self->get_schema;

    my %all_statuses    = map { $_->id => $_ } $schema->resultset( $class )->all;
    my @allow_statuses;
    my @not_allow_statuses;

    if ( $args->{exclude} ) {
        # get rid of any Statuses not required first
        delete $all_statuses{ $_ }      foreach ( @{ $args->{exclude} } );
    }

    if ( $args->{allow} ) {
        @allow_statuses     = sort { $a->id <=> $b->id }
                                map { delete $all_statuses{ $_ } }
                                    @{ $args->{allow } };
        @not_allow_statuses = sort { $a->id <=> $b->id }
                                values %all_statuses;
    }
    elsif ( $args->{not_allow} ) {
        @not_allow_statuses = sort { $a->id <=> $b->id }
                                map { delete $all_statuses{ $_ } }
                                    @{ $args->{not_allow } };
        @allow_statuses     = sort { $a->id <=> $b->id }
                                values %all_statuses;
    }
    else {
        croak "Didn't Specify either 'allow' or 'not_allow' Status Ids";
    }

    return {
            allowed     => \@allow_statuses,
            not_allowed => \@not_allow_statuses,
        };
}

1;

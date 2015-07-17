package Test::XTracker::Data::Reservation;
use NAP::policy 'test';

use Test::XT::Data;

=head1 NAME

Test::XTracker::Data::Reservation

=head1 DESCRIPTION

Create and manipulate test data related to reservations.

=head1 METHODS

=head2 create_reservations

Create one or more Reservations using L<Test::XT::Data::ReservationSimple>.

It takes two forms of argument, if given an integer, will create that number
of reservations using all the defaults:

    my @eservations = Test::XTracker::Data::Reservation
        ->create_reservations( 2 );

If given an ArrayRef of HashRefs, a new reservation will be created for each
entry in the ArrayRef. The keys and values in the HashRef correspond to
attributes to set on the L<Test::XT::Data> object:

    my @eservations = Test::XTracker::Data::Reservation
        ->create_reservations([
            { channel => $channel_object, customer => $customer_object }
            { channel => $channel_object, customer => $another_customer_object }
            ...
        ]);

=cut

sub create_reservations {
    my $class = shift;
    my ( $argument ) = @_;

    my @results;

    my @reservations = ref( $argument ) eq 'ARRAY'
        ? @{ $argument }
        : ( map {; {} } 1..$argument );

    foreach my $reservation ( @reservations ) {

        my $data= Test::XT::Data->new_with_traits(
            traits => [ 'Test::XT::Data::ReservationSimple' ],
        );

        my %methods = ref( $reservation ) eq 'HASH'
            ? %{ $reservation }
            : ();

        # Set all the attributes given in the Hash.
        foreach my $method ( keys %methods ) {
            $data->$method( $methods{ $method } )
                if $data->can( $method );
        }

        push @results, $data->reservation;

    }

    return @results;

}

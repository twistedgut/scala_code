package XTracker::Schema::Role::GetTelephoneNumber;
use NAP::policy "tt", 'role';
requires qw( telephone mobile_telephone );

=head1 XTracker::Schema::Role::GetTelephoneNumber

A role for getting a Telephone Number but starting with a particular choice such as 'mobile' and then
if that is empty (or contains no numbers) moving on to the next field.

Currently a Role for:
    * Public::Orders
    * Public::Shipment

=cut

=head2 get_phone_number

    $string = $self->get_phone_number( { start_with => 'mobile' } );

Will return a phone number or an empty string if there are no numbers in it or it's empty. Passing an optional 'start_with' argument
will mean it will start with that field and if it can't find anything move on to the next. By default it will start with 'telephone'
and then move on to 'mobile_telephone'.

=cut

sub get_phone_number {
    my ( $self, $args )     = @_;

    my %field_order = (
            default => [ qw(
                        telephone
                        mobile_telephone
                    ) ],
            mobile  => [ qw(
                        mobile_telephone
                        telephone
                    ) ],
        );
    my $start_with  = ( exists( $field_order{ $args->{start_with} // '' } ) ? $args->{start_with} : 'default' );

    my $number      = "";
    FIELD:
    foreach my $field ( @{ $field_order{ $start_with } } ) {
        $number = $self->$field;
        $number =~ s/[^\d\+]//g;
        $number =~ s/(?<!^)\+//g;       # take out every '+' unless it's the first one
        $number = ""            if ( length( $number ) <= 3 );

        # if $number isn't empty then stop
        last FIELD      if ( $number );
    }

    return $number;
}


1;

package XTracker::Utilities::DBIC::DateTimeFormat;

use strict;
use warnings;

use base    qw( DBIx::Class::Core );
use Carp    qw( croak );

use XTracker::Utilities ();     # () to prevent name space pollution & unwanted imports


=head1 XTracker::Utilities::DBIC::DateTimeFormat

A Collection of Date/Time formatting methods that can be applied to DateTime objects.

=head3 How to use

In your package:

 __PACKAGE__->load_components('+XTracker::Utilities::DBIC::DateTimeFormat');

And then, say your table has a C<date> method (or column):

    my $string  = $row->twelve_hour('date');

=head2 twelve_hour

    my $string  = $row->twelve_hour('date_column_name');

This returns a string formatting the DateTime object into a twelve hour human readable format including 'am' & 'pm' suffixes.

See: XTracker::Utilities::dt_twelve_hour_format() for more information.

=cut

sub twelve_hour {
    my ( $self, $method, %opts )    = @_;

    croak("You must provide a method name to twelve_hour()") unless $method;

    my $date_time   = $self->$method;
    return      unless $date_time;

    croak("'$method' doesn't return a DateTime object") unless ( ref( $date_time ) && $date_time->isa('DateTime') );

    return XTracker::Utilities::twelve_hour_time_format( $date_time, %opts );
}

1;

package XTracker::Utilities::DBIC::LocalDate;

use strict;
use warnings;

use base qw( DBIx::Class::Core );
use Carp qw(croak);
use XTracker::Utilities ();

=head2 local_date

 my $dt = $row->local_date('date_column_name');

=head3 What

Returns a clone of the L<DateTime> object returned by calling the method you
supply the name of, set to the correct timezone, and with the correct time
formatter set.

=head3 Why

Dates in the database are stored as UTC. Ha ha! No really. They're meant to be.
When you get a DBIC-inflated column back from it, you'll get a L<DateTime>
whose timezone is set to 'UTC'. That's all well and good, but if you'll be
using that to tell the user you'll want to set the timezone on it to the
application local time. Which you'll need to find out, and which should be set,
but only if you're using XTracker::Config::Local, and you can use that, but
that'll fail if it's not. And then if you actually change your DateTime object
you've changed the value in the DBIC row, and don't even think about committing
at that point and oh my.

=head3 How to use

In your package:

 __PACKAGE__->load_components('+XTracker::Utilities::DBIC::LocalDate');

And then, say your table has a C<date> method:

 my $correctly_localized_date_time_object =
    $row->local_date('date');

=head3 Options

We die if you use this on a column that produces a DateTime without a timezone
defined. That's not always optimal. You can B<BUT SHOULDN'T> pass in the
C<naughty_local_time_zone> flag if you understand this, and want to default to
the timezone.

=cut

sub local_date {
    my ( $self, $method, %opts ) = @_;
    croak("You must provide a method name to local_date()") unless $method;

    my $date_time = $self->$method;
    return undef unless $date_time;

    croak("'$method' doesn't return a DateTime object") unless
        ( ref $date_time && $date_time->isa('DateTime') );

    croak("The DateTime object returned by '$method' doesn't have a timezone, so can't convert to local time")
        if $date_time->time_zone->isa('DateTime::TimeZone::Floating') &&
            (! $opts{'naughty_local_time_zone'} );

    return XTracker::Utilities::local_date($date_time,%opts);
}



1;

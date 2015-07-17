package XTracker::Schema::ResultSet::SOS::WeekDay;
use NAP::policy "tt";
use base 'DBIx::Class::ResultSet';
use MooseX::Params::Validate;
use XTracker::Constants::FromDB qw/
    :sos_week_day
/;

=head1 NAME

XTracker::Schema::ResultSet::SOS::WeekDay

=head1 DESCRIPTION

Defines specialised methods for the WeekDay resultset

=head1 PUBLIC METHODS

=head2 get_sos_week_day_from_datetime

Given a DateTime object, return the SOS weekday object for that DateTime's weekday

param - $datetime : A DateTime object

return - $week_day : SOS Weekday constant

=cut

# This mapping matches the DateTime modules weekday identifiers to our own Primary Keys
my $DATETIME_TO_SOS_WEEKDAY_MAP = {
    1 => $SOS_WEEK_DAY__MONDAY,
    2 => $SOS_WEEK_DAY__TUESDAY,
    3 => $SOS_WEEK_DAY__WEDNESDAY,
    4 => $SOS_WEEK_DAY__THURSDAY,
    5 => $SOS_WEEK_DAY__FRIDAY,
    6 => $SOS_WEEK_DAY__SATURDAY,
    7 => $SOS_WEEK_DAY__SUNDAY,
};

sub get_sos_week_day_from_datetime {
    my ($self, $datetime) = validated_list(\@_,
        datetime => { isa => 'DateTime' },
    );
    return $self->find($DATETIME_TO_SOS_WEEKDAY_MAP->{$datetime->day_of_week()});
}

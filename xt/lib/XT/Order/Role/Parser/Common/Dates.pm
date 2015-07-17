package XT::Order::Role::Parser::Common::Dates;
use Moose::Role;
use DateTime::Format::Strptime;

sub _get_timezoned_date {
    my($self,$date,$to_timezone,$from_timezone) = @_;

    # Because we don't have a timezoned date string we assign one.
    # Generally we get the order through in London time
    if (!defined $from_timezone) {
        $from_timezone = 'Europe/London';
    }
    my $dt = $self->_translate_time($date,$from_timezone);

    if (defined $to_timezone) {
        $dt->set_time_zone($to_timezone);
    }

    return $dt;
}

sub _translate_time {
    my($self,$date,$timezone) = @_;
    my $fmt = DateTime::Format::Strptime->new(
        pattern   => '%Y-%m-%d %H:%M',
        time_zone => $timezone,
    );
    my $date_time_object = $fmt->parse_datetime($date); # '2009-10-28 17:10'
    return $date_time_object;
}

1;

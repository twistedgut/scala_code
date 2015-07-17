package XT::Data::DateStamp;
use NAP::policy "tt", "class", "overloads";

use DateTime;
use DateTime::Format::Strptime;

use XTracker::Config::Local qw( config_var );

has _datetime => (
    is  => "ro",
    isa => "DateTime",
    handles => [qw/
        compare
        day
        day_abbr
        day_name
        day_of_month
        day_of_week
        day_of_year
        delta_days
        epoch
        formatter
        is_infinite
        last_day_of_month
        month
        month_abbr
        month_name
        offset
        strftime
        time_zone
        year
        ymd
        iso8601
    /],
);

# Can't do vanilla delegation, these methods returns $self, not the
# Datetime object. $self needs to be this object, not the underlying
# DateTime object.
my $delegated_methods = [qw/
    add
    set_day
    set_formatter
    set_month
    set_time_zone
    set_year
    subtract
/];
for my $delegated_method (@$delegated_methods) {
    __PACKAGE__->meta->add_method(
        $delegated_method => sub {
            my $self = shift;
            $self->_datetime->$delegated_method(@_);
            return $self;
        },
    );
}

=head1 CLASS METHODS

=head2 from_datetime($datetime) : $date_stamp

Create a new DateStamp based on the DateTime/DateStamp $datetime. For
convenience sake, you can also pass in a DateStamp here and it'll do
the right thing.

If the TZ is important, it should already be set to a correct TZ.

=cut

sub from_datetime {
    my ($class, $datetime) = @_;
    defined($datetime) or return undef;
    $datetime->isa($class) and return $datetime->clone();

    my $self = $class->new({ _datetime => $datetime->clone });
    $self->set(); # Clear hms

    return $self;
}

=head2 from_string($date_string?) : $date_stamp | undef | die

Parse $date_string according to the ISO8601 (YYYY-MM-DD) format and
return a new DateStamp, or die if $date_string isn't a valid format
(see L<Time::ParseDate>).

=cut

sub from_string {
    my ($class, $date_string) = @_;
    $date_string or return undef;

    # Create parsers for our date formats
    my @parsers = ();

    # Basic ISO8601 date string format
    push @parsers, DateTime::Format::Strptime->new(
                       pattern   => qr/^%Y-%m-%d$/,
                       time_zone => "UTC",
                       on_error  => "undef", );

    # Common ISO8601 datetime string format defined for use in API
    # request/responses (Zulu)
    push @parsers, DateTime::Format::Strptime->new(
                       pattern   => qr/^%Y-%m-%dT%T.%3NZ$/,
                       time_zone => "UTC",
                       on_error  => "undef", );

    # Attempt to parse the date string with the defined parsers
    my $dt = undef;
    foreach my $parser (@parsers){
        $dt = $parser->parse_datetime($date_string);
        last if defined $dt;
    }

    # Report failure
    if(!defined $dt){
        die "($date_string) can't be parsed "
          . join ' or ', map { $_->pattern } @parsers;
    }

    return $class->from_datetime($dt);
}

=head2 today(%args?) : $today_date_stamp

Return a DateStamp (using optional %args) for the current date, in the
time zone of the current DC.

=cut

sub today {
    my ($class,@args) = shift;
    my %args = (
        time_zone => config_var("DistributionCentre", "timezone"),
        @args,
    );
    return $class->from_datetime( DateTime->now(%args) );
}

=head1 METHODS

=head2 set(%args) : $self

Like DateTime set(), but you can only specify the date parts.

=cut

sub set {
    my ($self,%args) = @_;
    return $self->_datetime->set(
        %args,
        hour       => 0,
        minute     => 0,
        second     => 0,
        nanosecond => 0,
    );
}

=head2 clone() : $clone_of_self

Return a clone of this DateStamp object.

=cut

sub clone {
    my $self = shift;
    return ref($self)->new({ _datetime => $self->_datetime->clone });
}

=head2 human : $date_string

Return d/m/Y string.

=cut

sub human {
    my $self = shift;
    return $self->strftime("%d/%m/%Y");
}

=head1 Stringification

Stringify as YYYY-MM-DD.

=cut

use overload(
    qw( "" ) => sub { shift->ymd }, # Stringify to e.g. "2011-02-23"
    fallback => 1,
);

# For Data::Printer
sub _data_printer {
    my ($self, $properties) = @_;
    return "$self";
}

# The JSON module looks for this method to serialize objects (that
# also requires you use the JSON option "convert_blessed")
sub TO_JSON {
    my ($self) = @_;
    return "$self";
}

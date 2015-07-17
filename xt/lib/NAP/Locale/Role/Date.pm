package NAP::Locale::Role::Date;

use NAP::policy "tt", qw( role );

with 'NAP::Locale::Role';

requires 'language';

use DateTime::Format::DateParse;
use DateTime::Format::Strptime;

=head1 NAME

NAP::Locale::Role::Date

=head1 DESCRIPTION

Moose Role to implement localisation of Dates.

Provides a formatted date string according to the NAP brand standard for
a full date and a partial (Day, Month, Date) date.

Takes either a DateTime object or a string as input. Optionally a format
string (in CLDR format) may be specified on called to the formatted_date
method.

=head1 SYNOPSIS

    use NAP::Locale;
    use DateTime;
    use XTracker::Handler;

    my $handler = XTracker::Handler();
    ...
    my $customer = ... # Get customer from schema

    my $loc = NAP::Locale( locale => 'de_DE',
                           customer => $customer
                         );

    my $dt = DateTime->now();
    print $loc->formatted_date($dt);

=head1 METHODS

=cut

# We are using CLDR format strings for dates
my %formats = (
    en  => {
        branded => 'MMMM d, y',
        unbranded => 'EEEE, MMMM d',
    },
    fr  => {
        branded => 'EEEE d MMMM y',
        unbranded => 'EEE d MMMM',
    },
    de  => {
        branded => 'd. MMMM y',
        unbranded => 'EEEE, d. MMMM',
    },
    zh  => {
        branded => 'y年M月d日,EEEE',
        unbranded => 'MMMMd日,E',
    },
);

=head2 formatted_date

* formatted_date($DateTimeObj);
* formatted_date("2013-01-01");
* formatted_date("Monday, January 7");

When called with a DateTime object or a recognised date string format
will return a date formatted as "%A, %B %e" or the localised equivilent.

* formatted_date($DateTimeObj, "MMMM y");

When called with the optional format string, which must be supplied in
CLDR format (see DateTime::Locale) will return the date formatted
accordingly.

=cut

sub formatted_date {
    my ($self, $date, $format, $branded) = @_;
    my $old_date = $date; # So we can return what we were passed unclobbered

    if ( ! $date ) {
        $self->logger->warn(__PACKAGE__ . ' called without input');
        return ""; # Return an empty string to avoid raising a warning
    }

    unless ( ref $date && $date->isa('DateTime') ) {
        $date = $self->_date_coerce_into_datetime($date);
    }

    return $old_date unless ref $date && $date->isa('DateTime');

    $date->set_locale($self->locale);

    my $date_format = $branded ? $formats{$self->language}->{branded} :
                                 ( $format ? $format :
                                   $formats{$self->language}->{unbranded}
                                 );

    return $date->format_cldr($date_format);
}

=head2 branded_date

When called with a DateTime object of a recognised date string will
return a branded date - that is a date string containing the full
date expressed according to the brand date stadard.

=cut

sub branded_date {
    my $self = shift;
    my $date = shift;

    return $self->formatted_date($date, undef, 1);
}

sub _date_coerce_into_datetime {
    my $self = shift;
    my $date = shift;

    # XTracker uses strftime with at least 16 date formats!
    # Date::Parse does not recognise all of them. Manually parse...

    # $formats hashref is keyed on the strftime format with the expected locale
    # to parse it under as the value.
    my $formats = {
        '%F'                        => 'en_GB',
        '%d-%m-%Y %R'               => 'en_GB',
        '%d-%B-%Y %H:%M'            => 'en_GB',
        '%F @ %H:%M:%S'             => 'en_GB',
        '%F  %H:%M:%S'              => 'en_GB',
        '%FT%T%z'                   => 'en_GB',
        '%A, %B %e'                 => 'en_US',
        '%A, %B  %e'                => 'en_US',
        '%A, %B %d'                 => 'en_US',
        '%d-%m-%Y %R'               => 'en_GB',
        '%d/%m/%Y'                  => 'en_GB',
        '%d.%b.%Y-%H.%M.%S'         => 'en_GB',
        '%d-%m-%Y'                  => 'en_GB',
        '%F %H:%M'                  => 'en_GB',
        '%F %T'                     => 'en_US',
        '%d.%b.%Y-%H.%M.%S'         => 'en_GB',
        '%Y-%m-%dT%H:%M:%S.%3N%z'   => 'en_US',
        '%B %d, %Y'                 => 'en_US',
        '%B %d %Y'                  => 'en_US',
        '%d.%m.%y'                  => 'en_GB',
        '%d.%m.%Y-%H.%M.%S'         => 'en_GB',
    };

    my $dt;

    while ( my ( $format, $locale ) = each %$formats ) {
        my $strp = DateTime::Format::Strptime->new(
            locale  => $locale,
            pattern => $format,
        );
        my $pdt = $strp->parse_datetime($date);

        if ( ref $pdt && $pdt->isa('DateTime') ) {
            $dt = $pdt->clone;
            last;
        }
    }

    # As a last resort fall back to DateTime::Format::DateParse BUT ...
    # we do not fall back for any date format which might not be valid
    # if parsed according to the stupid Date::Parse en_US assumption
    unless ( ( ref $dt && $dt->isa('DateTime') ) || $date =~ /\d+.\d+.\d+/ ) {
        # We don't do anything if the eval fails.
        eval { $dt = DateTime::Format::DateParse->parse_datetime( $date ); };
    }

    return unless ref $dt && $dt->isa('DateTime');

    return $dt;
}

package Test::NAP::Locale::Role::Date;

use NAP::policy "tt", qw( test );
use feature 'unicode_strings';

use parent 'NAP::Test::Class';

use NAP::Locale;
use Test::XTracker::Data::Locale;

use Lingua::EN::Inflect qw( ORD );

use DateTime::Locale;
use Encode;

sub test_formatted_date : Tests {
    my $expected = {
        en_US   => {
            branded     => 'MMMM d, y',
            unbranded   => 'EEEE, MMMM d',
        },
        fr_FR   => {
            branded     => 'EEEE d MMMM y',
            unbranded   => 'EEE d MMMM',
        },
        de_DE   => {
            branded     => 'd. MMMM y',
            unbranded   => 'EEEE, d. MMMM',
        },
        zh_CN   => {
            branded     => 'y年M月d日,EEEE',
            unbranded   => 'MMMMd日,E',
        },
    };

    {
        # (un)Setting $SIG{__WARN__} like this prevents Moose validation failure
        # messages polluting the output
        local $SIG{__WARN__} = sub {};

        dies_ok { NAP::Locale->new() }
                 "Cannot instantiate without params";
        dies_ok { NAP::Locale->new(locale => 'en_US') }
                 "Cannot instantiate with only locale";
        dies_ok { NAP::Locale->new(locale => 'en_US', customer => '1') }
                 "Cannot instantiate without a Schema customer object";
    }

    my $dt = DateTime->now();

    for my $locale (qw/de_DE fr_FR zh en_US/) {
        note( "\n\nLOCALE: $locale\n\n" );
        my $localised_dt = $dt->clone;
        $localised_dt->set_locale($locale);

        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);

        foreach my $format ( keys %{$expected->{$locale}} ) {
            note("\nFORMAT $format\n");
            my $branded = $format eq 'branded' ? 1 : undef;
            my $localised = $loc->formatted_date($dt, undef, $branded);

            ok( $localised eq $localised_dt->format_cldr($expected->{$locale}->{$format}),
                "$format date from DateTime Object"
              );
        }

        note("Testing coersion from string");

        foreach my $string_format ( "%F",
                                    "%d-%m-%Y %R",
                                    "%d-%B-%Y %H:%M",
                                    "%F @ %H:%M:%S",
                                    "%F  %H:%M:%S",
                                    "%FT%T%z",
                                    "%d/%m/%Y",
                                    "%F %T",
                                    "%F %H:%M",
                                    "%d.%b.%Y-%H.%M.%S",
                                    "%Y-%m-%dT%H:%M:%S.%3N%z",
                                    "%d-%m-%Y",
                                    "%A, %B %e",
                                    "%B %d, %Y"
                                    ) {
            my $dt = DateTime->new( year => 2013, month => '03', day => '07' );
            my $wrong = DateTime->new( year => 2013, month => '07', day => '03' );

            my $formatted_string = $dt->strftime($string_format);
            my $returned_string = $loc->formatted_date($formatted_string);

            # Check that we have a returned value at all.
            ok( $returned_string,
                "I parse format \"$string_format\" which produces - $formatted_string");

            # Check that the returned string is different from the English language string
            if ( $locale ne 'en_US' && $locale ne 'en_GB' ) {
                ok( $returned_string ne $formatted_string,
                    encode("UTF-8", "$returned_string does NOT match $formatted_string") );
            }
            else {
                # The return format is %A, %B %e so verify that the return value is different is not using that format
                if ( $string_format ne '%A, %B %e' ) {
                    ok( $returned_string ne $formatted_string,
                        "$returned_string does NOT match $formatted_string" );
                }

                # Check that the returned date is not equal to $wrong
                ok( $returned_string ne $wrong->strftime($string_format),
                    "Date in English $returned_string has not been wrongly parsed as American" );
            }

            # Test the specific formatting used in create RMA email
            my $rma_email = join(" ", $dt->month_name, ORD($dt->day_of_month), $dt->year);
            $returned_string = $loc->branded_date($rma_email);
            ok( $returned_string,
                encode("UTF-8",
                "branded_date $returned_string works with rma input $rma_email") );

        }

        note("Testing what happens when we pass in something other than a date");
        my $result = $loc->formatted_date("NOT A DATE");
        ok( $result eq 'NOT A DATE', "Invalid input returned unchanged");
    }
}


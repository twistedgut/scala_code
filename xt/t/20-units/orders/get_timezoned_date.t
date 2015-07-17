#!/usr/bin/env perl

use FindBin::libs;
use NAP::policy "tt", 'test';
use Test::XTracker::Data;
use XTracker::Config::Local qw/config_var/;
use XT::Order::Role::Parser::Common::Dates;
use DateTime;

my $test_date = '2012-09-14 14:00';

# all the from_timezone are set to Europe/London because this is assumed due
# to the lack of timezone when the datetime string is sent across
my $test_cases = {
    'DC1' => {
        setup => {
            date => $test_date,
            to_timezone => 'Europe/London',
            from_timezone => 'Europe/London',
        },
        expect => {
            timezone => 'Europe/London',
            dt_timezone => 'Europe::London',
        }
    },
    'DC2' => {
        setup => {
            date => $test_date,
            to_timezone => 'America/New_York',
            from_timezone => 'Europe/London',
        },
        expect => {
            timezone => 'America/New_York',
            dt_timezone => 'America::New_York',
        }
    },
    'DC3' => {
        setup => {
            date => $test_date,
            from_timezone => 'Europe/London',
            to_timezone => 'Asia/Hong_Kong',
        },
        expect => {
            timezone => 'Asia/Hong_Kong',
            dt_timezone => 'Asia::Hong_Kong',
        }
    }
};

my $test = $test_cases->{ Test::XTracker::Data->whatami } || undef;

isa_ok($test,'HASH','DC with test');
test_get_timezoned_date($test);

done_testing;


sub test_get_timezoned_date {
    my($test) = @_;
    my $setup = $test->{setup};
    my $expect = $test->{expect};
    my $timezone = config_var('DistributionCentre','timezone');

    is($timezone,$expect->{timezone},
        "config matches expected timezone - $expect->{timezone}");

    # the method we're testing
    my $dt = XT::Order::Role::Parser::Common::Dates->_get_timezoned_date(
        $setup->{date},
        $timezone,
    );


    # work out what the timezone should be
    my $expected_datetime = datetime_expected(
        $setup->{date},
        $setup->{from_timezone},
        $setup->{to_timezone},
    );


    is(
        $dt, $expected_datetime,
        "datetime matches expected datetime - "
            .$expected_datetime->strftime('%Y-%m-%d %H:%M'),
    );

    like(ref($dt->time_zone), qr/$expect->{dt_timezone}$/,
        'datetime matched expected timezone - '. $expect->{dt_timezone},
    );
}

sub datetime_expected {
    my($date_str,$from_timezone,$to_timezone) = @_;

    note "  from_timezone: $from_timezone";
    note "    to_timezone: $to_timezone";

    my $fmt = DateTime::Format::Strptime->new(
        pattern   => '%Y-%m-%d %H:%M',
        time_zone => $from_timezone,
    );

    my $dt = $fmt->parse_datetime($date_str);
    $dt->set_time_zone($to_timezone) if ($to_timezone);

    return $dt;
}



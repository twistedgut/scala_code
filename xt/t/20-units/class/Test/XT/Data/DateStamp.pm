
package Test::XT::Data::DateStamp;
use FindBin::libs;
use parent "NAP::Test::Class";

use NAP::policy "tt", 'test';

use DateTime;
use Scalar::Util qw/ refaddr /;


use Test::Exception;
use Test::More::Prefix qw/ test_prefix /;

use XT::Data::DateStamp;
use XTracker::Config::Local qw( config_var );

sub DateStamp_from_datetime : Tests() {
    my $self = shift;

    ok(my $today = XT::Data::DateStamp->today, "Got 'today'");
    isa_ok($today, "XT::Data::DateStamp", "    and it's the correct class");
    ok(! $today->isa("DateTime"), "    and it's not a DateTime");
    my $local_time_zone = config_var("DistributionCentre", "timezone");
    is(
        $today->time_zone->name,
        $local_time_zone,
        "    and it's got the correct time zone",
    );

    is(
        XT::Data::DateStamp->from_datetime(undef),
        undef,
        "from_datetime(undef) returns undef",
    );

    my $dt = DateTime->new(
        year       => 1989,
        month      => 3,
        day        => 23,
        hour       => 16,
        minute     => 2,
        second     => 33,
        nanosecond => 323,
    );
    isa_ok(
        my $datestamp = XT::Data::DateStamp->from_datetime($dt),
        "XT::Data::DateStamp",
        "from_datetime returns object with correct class",
    );
    isnt($dt, $datestamp, "  Not the same object");
    for my $what (qw/ year month day /) {
        is($datestamp->$what, $dt->$what, "    $what ok");
    }
    for my $what (qw/ hour minute second nanosecond /) {
        is(
            $datestamp->_datetime->$what,
            0,
            "    $what cleared ok in the delegation DateTime object",
        );
    }

    is("$datestamp", "1989-03-23", "Stringification ok");
    is($datestamp->human, "23/03/1989", "Human readable form ok");
}


sub DateStamp_from_datetime_datestamp : Tests() {
    my $self = shift;

    ok(my $today = XT::Data::DateStamp->today, "Got 'today'");
    ok(
        my $new_datestamp = XT::Data::DateStamp->from_datetime($today),
        "Created a new DateStamp using from_datetime",
    );
    is("$today", "$new_datestamp", "They are the same date");
}

sub DateStamp_from_string : Tests() {
    my $self = shift;

    is(XT::Data::DateStamp->from_string(), undef, "Missing string returns undef");

    test_from_string_ok("2010-01-03");
    test_from_string_ok("1923-12-03");
    test_from_string_ok("2120-12-03");
    test_from_string_ok("2120-12-03T00:00:00.000Z");

    test_from_string_malformed("hello 2010-12-12 world");
    test_from_string_malformed("2010-12-12 23:00");
    test_from_string_malformed("320-23/23");
    test_from_string_malformed("Monday");
}

sub test_from_string_malformed {
    my ($string) = @_;
    throws_ok(
        sub { XT::Data::DateStamp->from_string($string) },
        qr|^\($string\) can't be parsed|,
        "Malformed string ($string) cannot be parsed",
    );
}

sub test_from_string_ok {
    my ($string) = @_;

    my $datestamp = XT::Data::DateStamp->from_string($string);

    # Remove timestamp from string if present, for comparison
    ($string = $string) =~ s/T\d\d:\d\d:\d\d.\d\d\dZ//xms;

    is("$datestamp", $string, "Stringification returns correct parsed value ($string)");
    isa_ok($datestamp, "XT::Data::DateStamp");
    is(
        $datestamp->time_zone->name,
        "UTC",
        "    and it's got the UTC time zone",
    );

    return $datestamp;
}

sub DateStamp_clone : Tests() {
    my $self = shift;

    my $day       = XT::Data::DateStamp->from_string("2009-02-03");
    my $day_after = $day->clone;
    isa_ok($day_after, "XT::Data::DateStamp");
    isnt(refaddr $day, refaddr $day_after, "Cloned object isn't the same");
    isnt(
        refaddr $day->_datetime,
        refaddr $day_after->_datetime,
        "Cloned datetime object isn't the same",
    );

    $day_after->add(days => 1);
    is("$day"      , "2009-02-03", "Original date is the same");
    is("$day_after", "2009-02-04", "Clone + add ==> correct date");
}

sub DateStamp_delegation : Tests() {
    my $self = shift;
    my $datestamp = XT::Data::DateStamp->today();

    my $today    = XT::Data::DateStamp->today();
    isa_ok($today, "XT::Data::DateStamp", "->today has correct class");
    my $yesterday = $today->add(days => 1);
    isa_ok($yesterday, "XT::Data::DateStamp", "->add returns correct class");
    is(refaddr $today, refaddr $yesterday, "     and returns the correct object");
}

1;

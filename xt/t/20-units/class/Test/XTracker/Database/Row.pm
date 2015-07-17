package Test::XTracker::Database::Row;
use NAP::policy "tt",     'test';
use parent "NAP::Test::Class";

use Test::More::Prefix qw/ test_prefix /;

use XTracker::Database::Row;

sub transform_datetime : Tests() {
    my $self = shift;

    my $row = XTracker::Database::Row->new({ time => "2011-10-21 17:37:47+01"});

    $row->inflate({ time => "DateTime" });

    isa_ok($row->{time}, "DateTime", "time was properly inflated");
    is($row->{time}, "2011-10-21T17:37:47", "   to the correct value");
}

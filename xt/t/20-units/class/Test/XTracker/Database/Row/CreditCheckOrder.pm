package Test::XTracker::Database::Row::CreditCheckOrder;
use FindBin::libs;
use parent "NAP::Test::Class";

use NAP::policy "tt", 'test';


use Test::Exception;
use Test::More::Prefix qw/ test_prefix /;

use XTracker::Database::Row::CreditCheckOrder;
use XTracker::Config::Local qw( config_var );

sub nominated_credit_check_urgency__no_nominated_day : Tests() {
    my $self = shift;
    my $row = XTracker::Database::Row::CreditCheckOrder->new({});
    is($row->nominated_credit_check_urgency, 0, "No nominated_earliest_selection_time => 0");
}

sub nominated_credit_check_urgency : Tests() {
    my $self = shift;

    my $window_hours = 4;
    $self->test_urgency("way in the future  ", 1000,                     0);
    $self->test_urgency("before window start", ($window_hours * 60) + 1, 0);
    $self->test_urgency("at window start    ", ($window_hours * 60),     1);
    $self->test_urgency("inside window start", ($window_hours * 60) - 1, 1);
    $self->test_urgency("now                ", 0,                        1);
    $self->test_urgency("in the past        ", -1000,                    1);
}

sub test_urgency {
    my ($self, $description, $minutes_forward, $expected_urgency) = @_;

    my $now = DateTime->now();
    my $row = XTracker::Database::Row::CreditCheckOrder->new({
        nominated_earliest_selection_time => $now->clone->add(minutes => $minutes_forward),
    });
    is(
        $row->nominated_credit_check_urgency,
        $expected_urgency,
        "Selection Time $description ($minutes_forward) minutes is urgent($expected_urgency)",
    );
}



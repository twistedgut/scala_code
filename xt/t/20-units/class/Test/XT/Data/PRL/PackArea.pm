package Test::XT::Data::PRL::PackArea;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { extends "NAP::Test::Class" }

use Test::XTracker::RunCondition (
    prl_phase => "prl",
);

use XT::Data::PRL::PackArea;

# Auto-restore any changes to the induction capacity
sub _get_capacity_guard {
    my $self = shift;
    return XT::Data::PRL::PackArea->new()->get_capacity_guard();
}

sub induction_capacity : Tests() {
    my $self = shift;
    my $restore_induction_capacity_guard = $self->_get_capacity_guard();

    my $pack_area = XT::Data::PRL::PackArea->new();
    $pack_area->induction_capacity(24);

    is(
        $pack_area->induction_capacity,
        24,
        "Induction capacity written and read back",
    );
}

sub accepts_containers_for_induction : Tests() {
    my $self = shift;
    my $restore_induction_capacity_guard = $self->_get_capacity_guard();

    my $pack_area = XT::Data::PRL::PackArea->new();

    $pack_area->induction_capacity(-1);
    ok(
        ! $pack_area->accepts_containers_for_induction,
        "Definitely no induction_capacity means no accepts_containers_for_induction",
    );

    $pack_area->induction_capacity(0);
    ok(
        ! $pack_area->accepts_containers_for_induction,
        "No induction_capacity means no accepts_containers_for_induction",
    );

    $pack_area->induction_capacity(1);
    ok(
        $pack_area->accepts_containers_for_induction,
        "Positive induction_capacity means yes, it accepts_containers_for_induction",
    );

    $pack_area->induction_capacity(324);
    ok(
        $pack_area->accepts_containers_for_induction,
        "Large positive induction_capacity means yes, it accepts_containers_for_induction",
    );
}

sub test__remaining_capacity : Tests {
    my $self = shift;

    # Extremely basic sanity check
    my $pack_area = XT::Data::PRL::PackArea->new();
    ok($pack_area->remaining_capacity(), "remaining_capacity");

}

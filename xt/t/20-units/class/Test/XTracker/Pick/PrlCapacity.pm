package Test::XTracker::Pick::PrlCapacity;
use NAP::policy "tt", "test", "class";
BEGIN { extends "NAP::Test::Class" };
use Test::XTracker::RunCondition prl_phase => 2, pick_scheduler_version => 2;

=head1 NAME

Test::XTracker::Pick::PrlCapacity - Unit tests for XTracker::Pick::PrlCapacity

=cut

use XTracker::Constants::FromDB qw(
    :allocation_status
    :prl
);
use vars qw/ $PRL__FULL $PRL__DEMATIC $PRL__GOH /;



=head1 METHODS

=cut

sub prl_rs { shift->schema->resultset("Public::Prl") }

# This will primarily test the PrlCapacity, but also the creation of
# an object using a Prl row
sub test__as_prl_capacity__capacities : Tests {
    my $self = shift;

    my $picking_count = 50;

    note "*** Setup";
    my $full_prl_row = $self->prl_rs->find($PRL__FULL);
    my $picking_total_capacity = $full_prl_row->total_capacity("picking");
    my $staging_total_capacity = eval { $full_prl_row->total_capacity("staging") };
    my $staging_container_count = 10;
    my $staging_remaining_capacity
        = $staging_total_capacity
        - $picking_count
        - $staging_container_count;
    cmp_deeply(
        $full_prl_row->as_prl_capacity(
            { full => $picking_count },
            { full => $staging_container_count },
        ),
        methods(
            picking_remaining_capacity           => $picking_total_capacity - $picking_count,
            current_picking_remaining_capacity   => $picking_total_capacity - $picking_count,
            staging_remaining_capacity           => $staging_remaining_capacity,
            current_staging_remaining_capacity   => $staging_remaining_capacity,
            current_induction_remaining_capacity => 0,
        ),
        "Full as_prl_capacity looks ok",
    );

    my $goh_prl_row = $self->prl_rs->find($PRL__GOH);
    $picking_total_capacity = $goh_prl_row->total_capacity("picking");
    $staging_total_capacity = eval { $goh_prl_row->total_capacity("staging") };
    cmp_deeply(
        $goh_prl_row->as_prl_capacity(
            { goh => $picking_count },
            { goh => $staging_container_count },
        ),
        methods(
            picking_remaining_capacity           => $picking_total_capacity - $picking_count,
            current_picking_remaining_capacity   => $picking_total_capacity - $picking_count,
            staging_remaining_capacity           => undef,
            current_staging_remaining_capacity   => undef,
            current_induction_remaining_capacity => undef,
        ),
        "GOH as_prl_capacity looks ok",
    );

    my $dcd_prl_row = $self->prl_rs->find($PRL__DEMATIC);
    $picking_total_capacity = $dcd_prl_row->total_capacity("picking");
    $staging_total_capacity = eval { $dcd_prl_row->total_capacity("staging") };
    cmp_deeply(
        $dcd_prl_row->as_prl_capacity(
            { dcd => $picking_count },
            { dcd => $staging_container_count },
        ),
        methods(
            picking_remaining_capacity           => $picking_total_capacity - $picking_count,
            current_picking_remaining_capacity   => $picking_total_capacity - $picking_count,
            staging_remaining_capacity           => undef,
            current_staging_remaining_capacity   => undef,
            current_induction_remaining_capacity => undef,
        ),
        "DCD as_prl_capacity looks ok",
    );
}


package Test::XTracker::Schema::Result::Public::Prl;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with "Test::Role::WithSchema";
};
use Test::XTracker::RunCondition prl_phase => "prl";

=head1 NAME

Test::XTracker::Schema::Result::Public::Prl

=cut

use XTracker::Constants::FromDB qw(
    :allocation_status
    :prl
);
use vars qw/ $PRL__FULL $PRL__DEMATIC $PRL__GOH /;



=head1 METHODS

=cut

sub prl_config : Tests() {
    my $self = shift;

    # This is largely Johan's table of PRL properties transcribed into
    # a Perl hash. See http://jira4.nap/browse/DCA-3254
    # We'll need to add entries for Cage and Oversize later.
    my $tests = {
        Full => {
            display_name            => 'Full Warehouse',
            speed                   => 'slow',
            triggers_picks_by       => 'induction',
            allocates_pack_space_at => 'induction',
            pack_space_unit         => 'container',
            booleans                => {
                has_staging_area           => 1,
                has_container_transfer     => 0,
                has_induction_point        => 1,
                has_local_collection_point => 0,
                has_conveyor_to_packing    => 1,
            },
            triggers_picks_in       => ['Dematic'],
        },
        Dematic => {
            display_name            => 'DCD',
            speed                   => 'fast',
            triggers_picks_by       => undef,
            allocates_pack_space_at => 'pick',
            pack_space_unit         => 'allocation',
            booleans                => {
                has_staging_area           => 0,
                has_container_transfer     => 0,
                has_induction_point        => 0,
                has_local_collection_point => 0,
                has_conveyor_to_packing    => 1,
            },
            integrates_with         => ['GOH'],
            picks_triggered_by      => [qw(GOH Full Cage Oversize)],
        },
# Commented out until GOH is active
#        GOH  => {
#            display_name            => 'GOH',
#            speed                   => 'slow',
#            triggers_picks_by       => 'pick_complete',
#            allocates_pack_space_at => 'pick_complete',
#            pack_space_unit         => 'allocation',
#            booleans                => {
#                has_staging_area           => 0,
#                has_container_transfer     => 1,
#                has_induction_point        => 1,
#                has_local_collection_point => 0,
#                has_conveyor_to_packing    => 1,
#            },
#            triggers_picks_in       => ['DCD'],
#        },
    };

    my $prl_rs = $self->schema->resultset('Public::Prl');

    foreach my $prl_name (keys %$tests) {
        note "*** $prl_name\n";
        my $test = $tests->{$prl_name};
        my ($prl) = $prl_rs->search({
            name      => $prl_name,
            is_active => 1,
        });
        ok($prl, "Got a prl for $prl_name");
        isa_ok($prl, 'XTracker::Schema::Result::Public::Prl');
        is($prl->display_name, $test->{display_name},
           "Display name is $test->{display_name}");

        is($prl->prl_speed->name, $test->{speed},
           "Speed is $test->{speed}");

        if (defined $test->{triggers_picks_by}) {
            is($prl->prl_pick_trigger_method->name, $test->{triggers_picks_by},
               "Triggers picks by is $test->{triggers_picks_by}");
        } else {
            ok(!defined $prl->prl_pick_trigger_method,
               "Triggers picks by is undefined");
        }

        is ($prl->prl_pack_space_allocation_time->name,
            $test->{allocates_pack_space_at},
            "Allocates pack space at is $test->{allocates_pack_space_at}");

        is ($prl->prl_pack_space_unit->name, $test->{pack_space_unit},
            "Pack space unit is $test->{pack_space_unit}");

        foreach my $boolean (keys %{$test->{booleans}}) {
            is($prl->$boolean, $test->{booleans}->{$boolean},
               "$boolean value is correct");
        }

        if ($test->{integrates_with}) {
            my @integrations = $prl->integrates_with;
            is(scalar @integrations, scalar @{$test->{integrates_with}},
               'Correct number of integrations');
            for my $i (0 .. $#integrations) {
                is($integrations[$i]->name, $test->{integrates_with}->[$i],
                   "Integration $i is $test->{integrates_with}->[$i]");
            }
        }

        if ($test->{triggers_picks_in}) {
            my @triggers_picks_in = $prl->triggers_picks_in({}, {
                order_by => 'trigger_order'
            });
            is(scalar @triggers_picks_in, scalar @{$test->{triggers_picks_in}},
               'Correct number of triggers');
            foreach my $i (0 .. $#triggers_picks_in) {
                is($triggers_picks_in[$i]->name,
                   $test->{triggers_picks_in}->[$i],
                   "Triggers picks in $i is $test->{triggers_picks_in}->[$i]");
            }
        }

        if ($test->{picks_triggered_by}) {
            my @picks_triggered_by = $prl->picks_triggered_by({}, {
                order_by => 'trigger_order'
            });
            is(scalar @picks_triggered_by,
               scalar @{$test->{picks_triggered_by}},
               'Correct number of triggers');
            foreach my $i (0 .. $#picks_triggered_by) {
                is($picks_triggered_by[$i]->name,
                   $test->{picks_triggered_by}->[$i],
                   "Picks triggered by $i is $test->{picks_triggered_by}->[$i]");
            }
        }
    }
}

sub pick_complete_allocation_status : Tests {
    my $self = shift;

    my %test = (
        GOH  =>    $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
        Full =>    $ALLOCATION_STATUS__STAGED,
        Dematic => $ALLOCATION_STATUS__PICKED,
    );

    my $prl_rs = $self->schema->resultset('Public::Prl');

    while (my ($prl_name, $status) = each %test) {
        my $prl = $prl_rs->find({ name => $prl_name });
        is ($prl->pick_complete_allocation_status,
            $status,
            "$prl_name set pick_complete allocation status correctly");
    }
}

sub prl_rs { shift->schema->resultset("Public::Prl") }

sub integrates_with_prl : Tests {
    my $self= shift;

    my $prl_rs = $self->schema->resultset('Public::Prl');

    my $goh  = $prl_rs->find($PRL__GOH);
    my $full = $prl_rs->find($PRL__FULL);
    my $dcd  = $prl_rs->find($PRL__DEMATIC);

    ok(!$goh->integrates_with_prl($full), "GOH doesn't integrate with Full");
    ok( $goh->integrates_with_prl($dcd),  "GOH integrates with DCD");
    ok(!$full->integrates_with_prl($goh), "Full doesn't integrate with Full");
    ok(!$full->integrates_with_prl($dcd), "Full doesn't integrate with DCD");
    ok( $dcd->integrates_with_prl($goh),  "DCD integrates with GOH");
    ok(!$dcd->integrates_with_prl($full), "DCD doesn't integrate with Full");
}

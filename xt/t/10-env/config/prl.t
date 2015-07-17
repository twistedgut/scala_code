#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Config options for PRLs

Make sure that PRL config is sane.

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => ['$distribution_centre'];

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                ) );

use XT::Domain::PRLs;

note "Check that rollout_phase value is valid";

# Queue names should be in the format '/queue/dcN/prl_....', e.g. /queue/dc2/prl_base
my $queue_prefix = lc($distribution_centre);
my $queue_regex = qr#^/queue/$queue_prefix/prl_[a-z]+$#;

my $rollout_phase = config_var( 'PRL', 'rollout_phase');
like ($rollout_phase, '/^\d+$/', "rollout_phase is a number");

# If we're in a PRL rollout phase, we need to have some details
# of the actuak PRL(s)
if ($rollout_phase) {
    note "Check PRL details";
    my $prls = config_var( 'PRL', 'PRLs');
    isnt($prls, undef, 'PRLs entry exists in the config');
    is(ref $prls, 'HASH', 'Content of PRLs is correct type');
    cmp_ok(scalar keys %$prls,  '>=', 1, 'At least one PRL is defined');
    my @db_prls = XT::Domain::PRLs::get_all_prls();
    cmp_ok(scalar @db_prls,  '>=', 1, 'At least one PRL is defined in db');
    foreach my $prl (@db_prls) {
        note "Check " . $prl->name . " PRL";
        isnt($prl->amq_queue, undef, "$prl PRL has amq_queue defined");
        like($prl->amq_queue, $queue_regex, "$prl PRL has valid amq_queue name");
    }

    # We'll assume all systems with conveyors work the same, for now, but
    # we won't assume there's always a conveyor system because hopefully
    # we'll be rolling out DC3 PRL soon and that's very unlikely to have
    # one.
    my $conveyor = config_var( 'PRL', 'Conveyor');
    if ($conveyor) {
            note "Check conveyor config";
            ok ($conveyor->{Destinations}, "Some conveyor destinations are defined");
            ok ($conveyor->{PackLaneMessaging}, "Pack lane messaging section exists");
            ok ($conveyor->{PackLaneMessaging}->{routing_prefix},
                "Prefix for routing messages is defined");
            ok ($conveyor->{PackLaneMessaging}->{status_prefix},
                "Prefix for pack_lane_status messages is defined");
    }
}

done_testing;


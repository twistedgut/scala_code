package Test::XT::Warehouse;

use NAP::policy "tt", qw/class test/;

use Test::MockModule;

# See this module's docs for why we need this line
use Test::XTracker::LoadTestConfig;

use XT::Warehouse;
use XTracker::Config::Local;

BEGIN {
    extends 'NAP::Test::Class';
};

sub test_config_match : Tests {
    my $self = shift;

    # So we're not testing IWS rollout phase 1 as that doesn't really exist any
    # more and it's unlikely to exist in the future. This test should be
    # tweaked if/when we switch to IWS/PRLs being booleans rather than rollout
    # phases
    for ( [ 0,0 ], [ 0,1 ], [ 2,0 ], [ 2,1 ] ) {
        my ( $iws_rollout_phase, $prl_rollout_phase ) = @$_;
        subtest "running in IWS phase $iws_rollout_phase and PRL phase $prl_rollout_phase" => sub {
            # Let's mock config_var
            my $module = Test::MockModule->new('XTracker::Config::Local');
            $module->mock('config_var', sub {
                my ($section, $key) = @_;
                return ($section eq 'IWS' && $key eq 'rollout_phase') ? $iws_rollout_phase
                     : ($section eq 'PRL' && $key eq 'rollout_phase') ? $prl_rollout_phase
                     : XTracker::Config::Local::config_var(@_);
            });
            # For the warehouse object to use the mocked methods when creating
            # the singleton, we need to clear any existing instances of it
            XT::Warehouse->_clear_instance;
            my $warehouse = XT::Warehouse->instance;
            is( $warehouse->has_iws, !!$iws_rollout_phase,
                'has_iws returns correct value' );

            is( $warehouse->has_prls, !!$prl_rollout_phase,
                'has_prls returns correct value' );

            is( $warehouse->has_ravni, !$iws_rollout_phase && !$prl_rollout_phase,
                'has_ravni returns correct value' );
        }
    };
}

package XTracker::Role::WithIWSRolloutPhase;
use Moose::Role;

use XTracker::Config::Local qw( config_var );

has iws_rollout_phase => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => config_var('IWS', 'rollout_phase')
);

1;

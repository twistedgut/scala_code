package Test::Role::WithRolloutPhase;
use NAP::policy "tt", "role";
use XTracker::Config::Local;

# Lazy attributes to ensure the config is loaded before access.

has iws_rollout_phase => (
    is      => "ro",
    lazy    => 1,
    default => sub { config_var("IWS", "rollout_phase") },
);

has prl_rollout_phase => (
    is      => "ro",
    lazy    => 1,
    default => sub { config_var("PRL", "rollout_phase") },
);


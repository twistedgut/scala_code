package XTracker::Role::WithPRLs;
use Moose::Role;

use XTracker::Config::Local qw( config_var );
use XT::Domain::PRLs;

has prl_rollout_phase => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => config_var('PRL', 'rollout_phase')
);

has destinations => (
    is => 'rw',
    isa => 'ArrayRef|Undef',
    lazy => 1,
    default => sub {
        my @prls = XT::Domain::PRLs::get_all_prls();

        # We shouldn't get as far as caring about PRL producer destinations
        # if there are no PRLs defined in the config, but if that does happen
        # then now is not really the place to complain about it.
        return unless @prls;

        # They're always queues rather than topics.
        my @queues = map { $_->amq_queue } @prls;

        return \@queues;
    }
);

1;

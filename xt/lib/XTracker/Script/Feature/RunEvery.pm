package XTracker::Script::Feature::RunEvery;

use Moose::Role;

=head1 NAME

XTracker::Script::Feature::RunEvery

=head1 DESCRIPTION

This role ensures a script only runs if the epoch time is a multiple of a particular
number of minutes. The idea is to allow scripts that are run every minute from cron
to have a way of running, for example, every 7 minutes without needing a change to
the crontab entry.

=head1 SYNOPSIS

  package MyScript;
  use Moose;
  extends 'XTracker::Script';
  with 'XTracker::Script::Feature::RunEvery';

  sub invoke {
    # normal script stuff here - guaranteed to be on an interval multiple
  }

  1;

=cut

has interval => (
    isa => 'Int',
    is => 'rw',
    default => 1,
);

around invoke => sub {
    my ($orig, $self, %args) = @_;

    my $verbose = !!$args{verbose};

    # die if not at an interval multiple
    my $epoch = $self->epoch_time;
    my $interval = $self->interval || 1;
    my $this_minute = int( $epoch/60 );
    my $should_skip = !!( $this_minute % $interval );
    if ( $should_skip ) {
        $verbose && warn "Script $0 should run only at $interval-minute intervals\n";
        return;
    }

    $self->$orig(%args);
};

sub epoch_time {
    my ( $self ) = @_;
    # makes it easy to override this in test framework... don't do it otherwise! :)
    return time;
}

1;

package XTracker::Script::Feature::SingleInstance;

use Moose::Role;

=head1 NAME

XTracker::Script::Feature::SingleInstance

=head1 DESCRIPTION

This role ensures only a single instance of a given script runs at the same time.

=head1 SYNOPSIS

  package MyScript;
  use Moose;
  extends 'XTracker::Script';
  with 'XTracker::Script::Feature::SingleInstance';

  sub invoke {
    # normal script stuff here - always running alone
  }

  1;

=cut

use Fcntl ':flock';

has self_lock => (is => 'rw');

before BUILD => sub {
    my ($self, @args) = @_;

    # HACK: Under a shared Test::Class run if we have tests for more than one
    # module that consumes this role, the test will fall over as $0 will point
    # to the test class caller. So let's return if we detect we're running a
    # test.
    return if $ENV{HARNESS_ACTIVE};
    open(my $self_lock, '<', $0) or die "Can't open for locking - script $0 already running? ($!)";
    flock($self_lock, LOCK_EX | LOCK_NB) or die "Can't obtain lock - script $0 already running? ($!)";

    $self->self_lock($self_lock);
};

1;

package XTracker::Script;

use Moose;

=head1 NAME

XTracker::Script

=head1 DESCRIPTION

Base class for XTracker scripts to try to reduce code duplication.

=head1 SYNOPSIS

  package XTracker::Scripts::SomeDepartment::SomeScript;

  use Moose;
  extends 'XTracker::Script';

  sub invoke {
    my ($self, $args) = @_;
    # do your scripty stuff
    return 0;
  }

  1;

=cut

sub BUILD {
}

sub invoke {
    my ($self, $args) = @_;

    die "Default script does nothing - you need to override invoke().";
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

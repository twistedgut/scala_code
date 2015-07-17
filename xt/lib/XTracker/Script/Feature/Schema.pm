package XTracker::Script::Feature::Schema;

use NAP::policy "tt", 'role';

=head1 NAME

XTracker::Script::Feature::Schema

=head1 DESCRIPTION

This role provides the script with a schema and dbh for XTracker.

=head1 SYNOPSIS

  package MyScript;
  use Moose;
  extends 'XTracker::Script';
  with 'XTracker::Script::Feature::Schema';

  sub invoke {
    # $self->schema is a DBIx::Class::Schema object
    # $self->dbh is same as $self->schema->storage->dbh
  }

  1;

=cut

with 'XTracker::Role::WithSchema';

1;

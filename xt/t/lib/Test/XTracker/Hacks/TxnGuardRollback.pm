package Test::XTracker::Hacks::TxnGuardRollback;

# Adds an explicit rollback function to DBIx::Class::Storage::TxnScopeGuard,
# so that you can rollback when you want to without relying on the scope going
# away, which throws a warning.

use strict;
use warnings;

use DBIx::Class::Storage::TxnScopeGuard;

# Until they add one themselves... If we start getting redefined warnings,
# then they did it, and you can get rid of this...
*DBIx::Class::Storage::TxnScopeGuard::rollback = sub {
    my $self = shift;

    eval { $self->{storage}->txn_rollback };
    $self->{inactivated} = 1;
};

1;

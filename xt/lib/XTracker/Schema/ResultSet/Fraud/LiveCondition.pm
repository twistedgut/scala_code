package XTracker::Schema::ResultSet::Fraud::LiveCondition;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Moose;

with 'XTracker::Schema::Role::ResultSet::FraudCondition';

1;

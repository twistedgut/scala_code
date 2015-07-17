package XTracker::Schema::ResultSet::Fraud::StagingRule;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Moose;

with 'XTracker::Schema::Role::ResultSet::FraudRule';

sub get_rules_ordered_by_sequence {
    my $self = shift;
    return $self->search({}, {order_by => {-asc => 'rule_sequence'}})->all;
}


1;

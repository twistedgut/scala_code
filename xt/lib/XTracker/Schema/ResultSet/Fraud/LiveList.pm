package XTracker::Schema::ResultSet::Fraud::LiveList;

use NAP::policy 'role';
with 'XTracker::Schema::Role::ResultSet::FraudList';

use base 'DBIx::Class::ResultSet';

1;

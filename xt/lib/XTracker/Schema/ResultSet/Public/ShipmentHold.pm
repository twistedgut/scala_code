package XTracker::Schema::ResultSet::Public::ShipmentHold;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
        order_by => {
            id          => 'id',
            hold_date   => 'hold_date',
        }
    };


1;

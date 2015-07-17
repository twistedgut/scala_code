package XTracker::Schema::ResultSet::Public::PreOrderRefundItem;
# vim: ts=4 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
         order_by => { id => 'id' }
     },

     'XTracker::Schema::Role::ResultSet::Summable' => {
         sums => {
             total_value => [ qw( unit_price tax duty ) ]
         }
     };

1;

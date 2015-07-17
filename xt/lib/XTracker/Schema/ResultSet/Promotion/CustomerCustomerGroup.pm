package XTracker::Schema::ResultSet::Promotion::CustomerCustomerGroup;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

# Gets customer info specified by group for both websites
sub get_by_customer_and_group {
    my ( $resultset, $customer_id, $customer_group_id ) = @_;

    my $rs = $resultset->search(
        {
            customer_id         => $customer_id,
            customergroup_id    => $customer_group_id,
        },
        {
        },
    );

    return $rs;
}

sub get_by_join_data {
    my ( $resultset, $customer_id, $customer_group_id, $website_id ) = @_;

    my $ccg = $resultset->find(
        {
            customer_id         => $customer_id,
            customergroup_id    => $customer_group_id,
            website_id          => $website_id,
        },
        { key => 'join_data' },
    );

    return $ccg;
}

1;

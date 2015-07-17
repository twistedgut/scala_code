package XTracker::Schema::ResultSet::Public::AllocationItemLog;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

=head2 filter_by_shipment_ids

Given an array of shipment ids returns the allocation item log

=cut

sub filter_by_shipment_ids {
    my ($self, @shipment_ids) = @_;

    my $me  = $self->current_source_alias;
    my @rs = $self->search({
        'shipment_item.shipment_id' => { '-in' => [ @shipment_ids ] }
    }, {
        order_by => { '-desc' => [$me.'.date', $me.'.id'] },
        prefetch => [
            { 'operator' => 'department' },
            'allocation_item_status',
            'allocation_status',
            { 'allocation_item' => 'shipment_item' }
        ]
    })->all();

    return \@rs;

}

1;

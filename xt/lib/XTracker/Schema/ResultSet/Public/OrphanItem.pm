package XTracker::Schema::ResultSet::Public::OrphanItem;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';


=head2 create_orphan_item

Create a true orphan item on a strayed sku which just landed in a container

=cut

sub create_orphan_item {
    my ($rs,$sku,$container_id,$old_container_id,$operator_id) = @_;

    my $orphan_item;
    my $schema = $rs->result_source->schema;

    # Check if it's a voucher
    my $voucher = $schema->resultset('Voucher::Variant')
    ->find_by_sku($sku,undef,1);

    my $orphan_details = {
        operator_id      => $operator_id,
        old_container_id => $old_container_id
    };

    if ($voucher) {
        # It's a voucher
        $orphan_details->{voucher_variant_id} = $voucher->id;

    } else {
        my $variant = $schema->resultset('Public::Variant')
            ->find_by_sku($sku,undef,1);

        $orphan_details->{variant_id} = $variant->id;

    }

    $orphan_item = $schema->resultset('Public::OrphanItem')->new_result( $orphan_details );
    $orphan_item->orphan_item_into( $container_id );
    $orphan_item->insert;

}

=head2

Bunch of container-related stuff follows -- should probably be
refactored into a role shared with ShipmentItem.

=cut

sub unpick {
    my ($self) = @_;

    $self->reset;

    while (my $item = $self->next) {
        $item->unpick;
    }

    return $self->reset;
}

sub items_in_container {
    my ($self, $container, $options) = @_;

    my $search = {
        container_id => (
            ref($container) eq "ARRAY" ? { -in => $container } : $container
        ),
    };

    return $self->search_rs($search);
}

=head2 container_ids

Return an unordered but distinct list of container IDs that contain these shipment items.

=cut

sub container_ids {
    my ($self) = @_;

    return uniq ($self->get_column('container_id')->all);
}

=head2 containers

Return a result set of containers that contain these shipment items,
optionally filtered by a container status ID.

=cut

sub containers {
    my ($self,$status_id) = @_;

    my $cond = {};

    if (ref($status_id)) {
        $cond = { status_id => { -in => $status_id } };
    }
    elsif ($status_id) {
        $cond = { status_id => $status_id };
    }

    return $self->search_related('container',
                                 $cond,
                                 { distinct => 1 }
                             );
}

1;


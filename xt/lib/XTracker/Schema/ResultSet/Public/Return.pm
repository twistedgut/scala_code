package XTracker::Schema::ResultSet::Public::Return;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw( :return_status :return_item_status );

sub not_cancelled {
    my ($self) = @_;
    $self->search(
        { return_status_id => { '!=' => $RETURN_STATUS__CANCELLED } },
    );
}

sub delivery_id_to_rma_number {
    my ($self, $delivery_ids) = @_;
    my $returns_rs = $self->search({
        'delivery.id' => { IN => $delivery_ids }
    },{
        join => { 'link_delivery__returns' => 'delivery' },
        prefetch => { 'link_delivery__returns' => 'delivery' },
    });
    my $rma_numbers = {};
    foreach my $return ($returns_rs->all) {
        $rma_numbers->{$return->link_delivery__returns->first->delivery->id} = $return->rma_number;
    }
    return $rma_numbers;
}

sub in_processing {
    my ($self) = @_;
    my $alias = $self->current_source_alias;

    return $self->search({
        "$alias.return_status_id" => { -in => [
            $RETURN_STATUS__PROCESSING,
        ] },
    });
}

sub with_items_after_qc {
    my ($self) = @_;

    return $self->search({
        'return_items.return_item_status_id' => { -in => [
            $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED,
            $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED,
            $RETURN_ITEM_STATUS__PASSED_QC,
        ] },
    },{
        join => 'return_items',
    });
}

1;

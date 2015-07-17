package XTracker::Schema::ResultSet::Public::ReturnItem;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use XTracker::Constants::FromDB qw( :return_item_status );
use XTracker::Error;

use base 'DBIx::Class::ResultSet';


=head2 beyond_qc_stage

    $result_set = $return_item_rs->beyond_qc_stage;

Return Items that have gone past the Returns QC page which will also include the
following *_QC__* statuses:

   * $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED
   * $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED

because they were assigned after the Returns QC page on the Returns Faulty page.

=cut

sub beyond_qc_stage {
    my $self    = shift;

    my $result = $self->not_cancelled->search( {
        return_item_status_id => { 'NOT IN' => [
            $RETURN_ITEM_STATUS__AWAITING_RETURN,
            $RETURN_ITEM_STATUS__BOOKED_IN,
            $RETURN_ITEM_STATUS__PASSED_QC,
            $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
        ] }
    } );

    return $result;
}

# Returns items that can be refunded
sub passed_qc {
    my ( $resultset ) = shift;

    my $result = $resultset->search( [
        { return_item_status_id => $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED, },
        { return_item_status_id => $RETURN_ITEM_STATUS__PASSED_QC, },
    ] );

    return $result;
}

# Return Items that have Failed QC and Awaiting a Decision
sub failed_qc_awaiting_decision {
    my $self    = shift;

    my $result = $self->search(
        {
            return_item_status_id => $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
        }
    );

    return $result;
}

# returns the number of active items in a return (non-cancelled items)
sub active_item_count {
    my ( $self ) = @_;

    return $self->not_cancelled->count;
}

sub by_shipment_item {
    my ($self, $shipment_item) = @_;

    my $id = ref($shipment_item) ? $shipment_item->id : $shipment_item;

    $self->search({
      shipment_item_id => $id
    })->first;
}

sub not_cancelled {
    my ($self) = @_;

    return $self->search_rs({
      return_item_status_id => { '!=' => $RETURN_ITEM_STATUS__CANCELLED, }
    });
}

sub cancelled {
    my ($self) = @_;

    return $self->search_rs({
      return_item_status_id => $RETURN_ITEM_STATUS__CANCELLED,
    });
}

sub find_by_sku {
    my ($self, $sku) = @_;

    my $joined_rs = $self->search( { }, { join => 'shipment_item' } );

    # Use a sub goto rather than a fn call so that the error comes from the right place
    @_ = ($joined_rs, $sku);
    goto \&XTracker::Schema::ResultSet::Public::ShipmentItem::find_by_sku;
}

=head2 update_exchange_item_id( $shipment_item_id, $exchange_shipment_item_id, $type )

  $return_item->update_exchange_item_id($x,$y,$type);

Update return_item set exchange_shipment_item_id=y or where either shipment_item_id=x or exchange_shipment_id=x depending on $type

=cut
sub update_exchange_item_id {
    my($self,$shipment_item_id,$exchange_shipment_item_id,$type)    = @_;

    my $types   = {
            'exchange'  => 'exchange_shipment_item_id',
            'shipment'  => 'shipment_item_id',
        };

    if ( !defined $type || !exists $types->{$type} ) {
        die "Type not passed in or not recognised don't know what to search on!";
    }

    my $to_update_rs = $self->search({ $types->{$type} => $shipment_item_id }); # FIXED

    # we got something back, update the lot!
    if ($to_update_rs) {
        $to_update_rs->update({ exchange_shipment_item_id => $exchange_shipment_item_id });

        return $to_update_rs->count;
    } else {
        warn sprintf "couldn't get a returnitem for exchange_shipment_item_id %d to update to %d",
            $shipment_item_id, $exchange_shipment_item_id;
    }

    return;
}

1;

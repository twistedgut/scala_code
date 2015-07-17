use utf8;
package XTracker::Schema::Result::Public::ReturnItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.return_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "return_item_id_seq",
  },
  "return_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "return_item_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "customer_issue_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "return_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "return_airway_bill",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "creation_date",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "exchange_shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "customer_issue_type",
  "XTracker::Schema::Result::Public::CustomerIssueType",
  { id => "customer_issue_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "exchange_shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "exchange_shipment_item_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "link_delivery_item__return_items",
  "XTracker::Schema::Result::Public::LinkDeliveryItemReturnItem",
  { "foreign.return_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "return",
  "XTracker::Schema::Result::Public::Return",
  { id => "return_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "return_item_status_logs",
  "XTracker::Schema::Result::Public::ReturnItemStatusLog",
  { "foreign.return_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::ReturnItemStatus",
  { id => "return_item_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::ReturnType",
  { id => "return_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EUIuu+y/Pu7xK4ifTgYOpQ

use XTracker::Constants::FromDB qw(
    :customer_issue_type
    :pws_action
    :return_item_status
    :return_type
    :shipment_item_status
);
use XTracker::Database::Return qw(get_return_invoice);
use XTracker::Database::Invoice qw(get_invoice_value);
use MooseX::Params::Validate;
use MooseX::Types::Common::Numeric qw/PositiveInt/;
use NAP::XT::Exception::Stock::InvalidReturnReverse;

__PACKAGE__->many_to_many(
    'delivery_items', link_delivery_item__return_items => 'delivery_item'
);

=head2 update_status( $status_id, $operator_id )

Update the row to the given C<$status_id> and log the change.

=cut

sub update_status {
    my ( $self, $status_id, $operator_id ) = @_;

    $self->result_source->schema->txn_do( sub {
        $self->update( { return_item_status_id => $status_id } );

        $self->create_related('return_item_status_logs', {
            return_item_status_id => $status_id,
            operator_id           => $operator_id,
        });
    });
    return $self;
}

sub reason {
    $_[0]->customer_issue_type->description;
}

sub status_str {
    $_[0]->status->status;
}

sub is_complete {
    shift->has_been_qced;
}

sub is_exchange {
    return $_[0]->return_type_id == $RETURN_TYPE__EXCHANGE;
}

sub is_refund {
    return not $_[0]->return_type_id == $RETURN_TYPE__EXCHANGE;
}

sub is_awaiting_return {
    return $_[0]->return_item_status_id == $RETURN_ITEM_STATUS__AWAITING_RETURN;
}

=head2 can_reverse

Returns 1 if it is possible for this return item to be reversed

=cut
sub can_reverse {
    my ($self) = @_;
    my $status_id = $self->return_item_status_id();
    return ((grep { $status_id == $_ } (
        $RETURN_ITEM_STATUS__AWAITING_RETURN,
        $RETURN_ITEM_STATUS__BOOKED_IN
    )) ? 1 : 0 );
}

=head2 is_booked_in

Returns a true value if the item has a status of B<Booked In>.

=cut

sub is_booked_in {
    return shift->return_item_status_id == $RETURN_ITEM_STATUS__BOOKED_IN;
}

=head is_passed_qc

Returns a true value if the item has a status of B<Passed QC>.

=cut

sub is_passed_qc {
    return shift->return_item_status_id == $RETURN_ITEM_STATUS__PASSED_QC;
}

=head2 is_failed_qc_awaiting_decision

Returns a true value if the item has a status of B<Failed QC - Awaiting Decision>.

=cut

sub is_failed_qc_awaiting_decision {
    return shift->return_item_status_id == $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION;
}

=head2 is_failed_qc_rejected

Returns a true value if the item has a status of B<Failed QC - Rejected>.

=cut

sub is_failed_qc_rejected {
    shift->return_item_status_id == $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED;
}

=head2 is_failed_qc_accepted

Returns a true value if the item has a status of B<Failed QC - Accepted>.

=cut

sub is_failed_qc_accepted {
    shift->return_item_status_id == $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED;
}

sub is_cancelled {
    return $_[0]->return_item_status_id == $RETURN_ITEM_STATUS__CANCELLED;
}

=head2 is_putaway_prep

Returns TRUE if the Item's Status is B<Putaway Prep>.

=cut

sub is_putaway_prep {
    my $self = shift;
    return ( $self->return_item_status_id == $RETURN_ITEM_STATUS__PUTAWAY_PREP ? 1 : 0 );
}

=head2 is_put_away

Returns TRUE if the Item's Status is B<Put Away>.

=cut

sub is_put_away {
    my $self = shift;
    return ( $self->return_item_status_id == $RETURN_ITEM_STATUS__PUT_AWAY ? 1 : 0 );
}

=head2 has_been_qced

Returns a true value if the item has not finished QC yet.

=head3 NOTE

You can use this method, together with L<is_exchange>, to completely replace
L<XTracker::Database::Return::check_return_complete>.

=cut

sub has_been_qced {
    my $self = shift;
    return !$self->is_awaiting_return
        && !$self->is_booked_in
        && !$self->is_failed_qc_awaiting_decision;
}

=head2 uncancelled_delivery_item

We should only ever have one uncancelled delivery item row linked to this
return item, and this method returns it.

=cut

sub uncancelled_delivery_item {
    return shift->delivery_items->find({ cancel => 0 });
}

sub date_received {
    my ($self) = @_;

    my $row = $self->return_item_status_logs
                   ->search({ return_item_status_id => $RETURN_ITEM_STATUS__BOOKED_IN })
                   ->first;

    return unless $row;
    return $row->date;
}

# Date when the exchange item was shipped
sub exchange_ship_date {
    my ($self) = @_;

    my $si = $self->exchange_shipment_item;

    return if (!$si || $si->is_pre_dispatch);

    return $si->shipment->dispatched_date;
}

sub refund_date {
    my ($self) = @_;

    my $renum = $self->return->renumerations->not_cancelled->first;

    return unless $renum && $renum->is_completed;

    return $renum->completion_date;
}

sub get_uncancelled_exchange_shipment_item{
    my $self = shift;
    my @statuses = (
                    $SHIPMENT_ITEM_STATUS__NEW,
                    $SHIPMENT_ITEM_STATUS__SELECTED,
                    $SHIPMENT_ITEM_STATUS__PICKED,
                    $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                    $SHIPMENT_ITEM_STATUS__PACKED,
                    $SHIPMENT_ITEM_STATUS__DISPATCHED,
                    $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                    $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                    $SHIPMENT_ITEM_STATUS__RETURNED
                    );
    my $exchange_shipment_item = $self->exchange_shipment_item;
    if ($exchange_shipment_item){
        SMARTMATCH: {
            use experimental 'smartmatch';
            return $exchange_shipment_item->id if $exchange_shipment_item->shipment_item_status_id() ~~ @statuses;
        }
    }
    return;

}

=head2 set_failed_qc_fixed

Set this item's status to B<Failed QC - Fixed>.

=cut

sub set_failed_qc_fixed {
    my ( $self, $operator_id ) = @_;

    die "This item can't be processed as it's in an incorrect state\n"
        unless ( $self->is_failed_qc_accepted || $self->is_failed_qc_rejected );

    return $self->update_status($RETURN_ITEM_STATUS__FAILED_QC__DASH__FIXED, $operator_id);
}

=head2 set_failed_qc_rtv

Set this item's status to B<Failed QC - RTV>.

=cut

sub set_failed_qc_rtv {
    my ( $self, $operator_id ) = @_;

    die "This item can't be processed as it's in an incorrect state\n"
        unless ( $self->is_failed_qc_accepted || $self->is_failed_qc_rejected );

    return $self->update_status($RETURN_ITEM_STATUS__FAILED_QC__DASH__RTV, $operator_id);
}

=head2 set_failed_qc_deadstock

Set this item's status to B<Failed QC - DeadStock>.

=cut

sub set_failed_qc_deadstock {
    my ( $self, $operator_id ) = @_;

    die "This item can't be processed as it's in an incorrect state\n"
        unless ( $self->is_failed_qc_accepted || $self->is_failed_qc_rejected );

    return $self->update_status($RETURN_ITEM_STATUS__FAILED_QC__DASH__DEADSTOCK, $operator_id);
}

=head2 set_failed_qc_accepted

Set this item's status to B<Failed QC - Accepted>.

=cut

sub set_failed_qc_accepted {
    my ( $self, $operator_id ) = @_;
    return $self->update_status($RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED, $operator_id);
}

=head2 set_failed_qc_rejected

Set this item's status to B<Failed QC - Rejected>.

=cut

sub set_failed_qc_rejected {
    my ( $self, $operator_id ) = @_;
    return $self->update_status($RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED, $operator_id);
}

=head2 set_returned_to_customer

Set this item's status to B<Returned to Customer>.

=cut

sub set_returned_to_customer {
    my ( $self, $operator_id ) = @_;
    return $self->update_status($RETURN_ITEM_STATUS__RETURNED_TO_CUSTOMER, $operator_id);
}

=head2 accept_failed_qc

Accept an item that has failed QC but we have accepted anyway.

=cut

sub accept_failed_qc {
    my ( $self, $operator_id ) = @_;

    die "This item can't be processed as it's in an incorrect state\n"
        unless $self->is_failed_qc_awaiting_decision;

    $self->result_source->schema->txn_do(sub{
        $self->set_failed_qc_accepted( $operator_id );
        $self->shipment_item->set_returned( $operator_id );
    });
    return $self;
}

=head2 incomplete_stock_process

Return the stock process for this return item. There should only ever be one
incomplete stock process per return item, and it should be part of an
uncancelled delivery item.

=cut

sub incomplete_stock_process {
    return shift->delivery_items
                ->search({ 'delivery_item.cancel' => 0 })
                ->related_resultset('stock_processes')
                ->find({ 'stock_processes.complete' => 0});
}

=head2 return_to_customer( $operator_id )

Updates statuses for this item, its shipment item and the related stock process
row.

=head3 NOTE

We tell IWS nothing because this item is either shipped completely manually, or
via a re-shipment which to make our lives easier we are trying to hide from IWS

=cut

sub return_to_customer {
    my ( $self, $operator_id ) = @_;

    die "This item can't be processed as it's in an incorrect state\n"
        unless ( $self->is_failed_qc_accepted || $self->is_failed_qc_rejected );

    $self->result_source->schema->txn_do(sub{
        $self->incomplete_stock_process->update({complete => 1});
        $self->set_returned_to_customer( $operator_id );
        $self->shipment_item->set_dispatched( $operator_id );
    });
    return $self;
}

=head2 send_to_rtv_customer_repair( \%args )

I B<think> this is when we send the item to RTV for repair so we can then send
it back to the customer, or something...

=head3 You can pass the following arguments

=over

=item fault_description

=item fault_type_id

=item uri_path

=item amq

=item operator_id

=back

=cut

sub send_to_rtv_customer_repair {
    my ( $self, $args ) = @_;

    die "This item can't be processed as it's in an incorrect state\n"
        unless $self->is_failed_qc_awaiting_decision;

    $self->result_source->schema->txn_do(sub{
        $self->accept_failed_qc( $args->{operator_id} );
        $self->incomplete_stock_process->send_to_rtv_customer_repair({ origin => 'returns', %$args });
    });
    return $self;
}

=head2 reject_failed_qc( $stock_manager, $operator_id )

Reject this failed QC item. Returns a hashref of renumeration ids with values
to adjust them. Also cancels any exchange shipment items for this return item.

=cut

# Apologies for all the old-school XTracker::Database, but I've already spent
# enough time porting this to DBIC and my head is beginning to hurt... it's
# good enough for now.
sub reject_failed_qc {
    my ( $self, $stock_manager, $operator_id ) = @_;

    die "This item can't be processed as it's in an incorrect state\n"
        unless $self->is_failed_qc_awaiting_decision;

    $self->set_failed_qc_rejected($operator_id);

    ### alter refund or delete item from exchange if neccessary
    ###########################################################

    my $schema = $self->result_source->schema;
    my $dbh = $schema->storage->dbh;
    my $renums = get_return_invoice($dbh, $self->return_id);

    my $renums_to_adjust;
    $schema->txn_do(sub{
        # We need to do some extra logic if we have an exchange shipment
        if ( $self->is_exchange ) {
            my $si = $self->exchange_shipment_item;
            $si->cancel({
                operator_id            => $operator_id,
                customer_issue_type_id => $CUSTOMER_ISSUE_TYPE__8__CANCELLED_EXCHANGE,
                pws_action_id          => $PWS_ACTION__CANCELLATION,
                notes                  => 'Rejected return for exchange shipment ' . $si->shipment_id,
                stock_manager          => $stock_manager,
            });

            my $shipment = $si->shipment;
            # cancel exchange shipment if only one item in it and it's not
            # dispatched, cancelled or lost
            $shipment->set_cancelled( $operator_id )
                if $shipment->shipment_items->count == 1
                && !$shipment->is_dispatched
                && !$shipment->is_cancelled
                && !$shipment->is_lost;
        }

        # if any items in refund remove them
        for my $renumeration (
            $schema->resultset('Public::Renumeration')
                   ->search({ id => [keys %$renums] })
                   ->all
        ) {
            # check if there's still something to do with the renumeration
            next if ( grep {
                $_->is_printed || $_->is_completed || $_->is_cancelled
            } $renumeration );

            # There should probably be a unique constraint
            # renumeration_item(renumeration_id, shipment_item_id)... but using
            # search_related as we can't add one due to bad data in (at least)
            # DC1. Anyway, delete any 'completed' renumeration items and
            # recalculate the tenders if we did so
            my $recalc_tenders
                = $renumeration->search_related('renumeration_items', {
                    shipment_item_id => $self->shipment_item_id }
                )->delete
                ? 1 : 0;

            $renums_to_adjust->{$renumeration->id} = get_invoice_value($dbh, $renumeration->id)
                if $recalc_tenders;
        }
    });

    return $renums_to_adjust;
}

=head2 putaway_prep_complete

Do whatever needs to be done to mark that putaway prep is complete on this
return item.

=cut

sub putaway_prep_complete {
    my ($self, $operator_id) = @_;

    $self->update_status($RETURN_ITEM_STATUS__PUTAWAY_PREP, $operator_id);
}

=head2 reverse_item

Reverse the return of this item

param - operator_id : Identifier for the operatator that performed this action

return - $ok : Returns true if action is completed

=cut
sub reverse_item {
    my ($self, $operator_id) = validated_list(\@_,
        operator_id => { isa => PositiveInt },
    );

    # Make sure this is allowed
    NAP::XT::Exception::Stock::InvalidReturnReverse->throw() unless $self->can_reverse();

    $self->result_source()->schema()->txn_do(sub {

        # reverse return item
        $self->update_status($RETURN_ITEM_STATUS__AWAITING_RETURN, $operator_id);

        # update shipment item status
        $self->shipment_item()->update_status($SHIPMENT_ITEM_STATUS__RETURN_PENDING, $operator_id);

        # Cancel the delivery items for this return item.
        my $delivery_item_rs = $self->delivery_items();
        $delivery_item_rs->update({ cancel => 1 });

        # Mark the stock process as complete. There should only ever be one
        # stock process for a delivery item linked to a return
        $delivery_item_rs->related_resultset('stock_processes')->update({complete => 1});

        # If we are cancelling the last delivery item in a delivery, this
        # should also trigger the cancellation of the delivery itself.
        my @deliveries = $delivery_item_rs->distinct_deliveries();
        for my $delivery (@deliveries) {
            next if $delivery->delivery_items->uncancelled->count;
            # Calling $delivery->cancel only works for stock orders
            $delivery->update({ cancel => 1 });
        }
    });

    return 1;
}

1;

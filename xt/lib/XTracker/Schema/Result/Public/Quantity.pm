use utf8;
package XTracker::Schema::Result::Public::Quantity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.quantity");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "quantity_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "zero_date",
  { data_type => "timestamp", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date_created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"('now'::text)::timestamp with time zone",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "location",
  "XTracker::Schema::Result::Public::Location",
  { id => "location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Flow::Status",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RW9IBWsjsSbjII0LrtRY/A

__PACKAGE__->belongs_to(
    'product_variant' => 'XTracker::Schema::Result::Public::Variant',
    { 'foreign.id' => 'self.variant_id' },
    { cascade_delete => 0 },
    { join_type => 'LEFT' },
);

__PACKAGE__->belongs_to(
    'voucher_variant' => 'XTracker::Schema::Result::Voucher::Variant',
    { 'foreign.id' => 'self.variant_id' },
    { cascade_delete => 0 },
    { join_type => 'LEFT' },
);

# This would be better modelled with an rtv_quantity.quantity_id FK. In the
# meanwhile we try and pick the correct item of stock by doing a join on the
# columns from this table that we'd be referencing.
__PACKAGE__->might_have(
    "rtv_quantity",
    "XTracker::Schema::Result::Public::RTVQuantity",
    {
        'foreign.variant_id'  => 'self.variant_id',
        'foreign.location_id' => 'self.location_id',
        'foreign.channel_id'  => 'self.channel_id',
        'foreign.status_id'   => 'self.status_id',
    },
    {},
);

use Moose;
use MooseX::Params::Validate 'validated_list';
use Carp;
with 'XTracker::Role::WithPRLs';

use XTracker::Logfile qw(xt_logger);
use XTracker::Constants::FromDB qw(
    :flow_status
    :shipment_hold_reason
    :shipment_status
);

# TODO: Get schema_loader to generate this automatically once TP-628 has been
# resolved - replace all instances of this constraint with the new constraint
# name if it changes.
__PACKAGE__->add_unique_constraint('quantity_id_key',
    [ qw{variant_id location_id channel_id status_id} ]);

__PACKAGE__->resultset_class('XTracker::Schema::ResultSet::Public::Quantity');

=head2 variant

Return a product or voucher variant.

=cut

sub variant {
    return $_[0]->product_variant || $_[0]->voucher_variant;
}

sub product {
    my ($self) = @_;
    return $self->variant->product();
}

=head2 update_quantity( $delta ) : quantity_row

Updates the quantity column with the given C<$delta>. Note that this method
B<doesn't> delete the row if there's 0 quantity left or warn if the quantity is
negative - these checks will need to be done by the caller where required.

=cut

sub update_quantity {
    my ( $self, $delta ) = @_;

    # Let pg deal with concurrency here. We need the additional discard_changes
    # call so the quantity field is set correctly in the object.
    return $self
        ->update({ quantity => \[ 'quantity + ?', [ delta => $delta ] ]})
        ->discard_changes;
}

sub delete_and_log {
    my ($self, $operator_id) = @_;
    $self->result_source->schema->resultset('Public::LogLocation')->create({
        variant_id  => $self->variant_id,
        location_id => $self->location_id,
        channel_id  => $self->channel_id,
        operator_id => $operator_id,
    });
    $self->delete;
}

=head2 update_and_log_sample({delta => $delta, operator_id => $operator_id, notes => $notes})

Update the quantity for this row with the given amount and log into log_sample.

=cut

sub update_and_log_sample {
    my ( $self, $args ) = @_;

    croak sprintf(
        'You only have %d items available at quantity_id %d, you tried to remove %d',
        $self->quantity, $self->id, $args->{delta}
    ) if $self->quantity + $args->{delta} < 0;

    my $schema = $self->result_source->schema;
    my $operator = $schema->resultset('Public::Operator')->find($args->{operator_id});
    $schema->txn_do(sub{
        $self->update_quantity($args->{delta});
        $self->channel->create_related('log_sample_adjustments', {
            sku           => $self->variant->sku,
            location_name => $self->location->location,
            operator_name => $operator->name,
            notes         => $args->{notes},
            delta         => $args->{delta},
            balance       => $self->quantity,
        });
        $self->delete unless $self->quantity;
    });
}

=head2 is_in_main_stock

Returns true if the status for this stock is B<Main Stock>.

=cut

sub is_in_main_stock {
    return shift->status_id == $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
}

=head2 is_in_dead_stock

Returns true if the status for this stock is B<Dead Stock>.

=cut

sub is_in_dead_stock {
    return shift->status_id == $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS;
}

=head2 is_in_transit_from_iws

Returns true if the status for this stock is B<In transit from IWS>.

=cut

sub is_in_transit_from_iws {
    return shift->status_id == $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS;
}

=head2 is_in_transit_from_prl

Returns true if the status for this stock is B<In transit from PRL>.

=cut

sub is_in_transit_from_prl {
    return shift->status_id == $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS;
}

=head2 is_transfer_pending

Returns true if the status for this stock is B<Transfer Pending>.

=cut

sub is_transfer_pending {
    return shift->status_id == $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS;
}

=head2 is_rtv_transfer_pending

Returns true if the status for this stock is B<RTV Transfer Pending>.

=cut

sub is_rtv_transfer_pending {
    return shift->status_id == $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS;
}

=head2 is_in_quarantine

Returns true if the status for this stock is B<Quarantine>.

=cut

sub is_in_quarantine {
    return shift->status_id == $FLOW_STATUS__QUARANTINE__STOCK_STATUS;
}

=head2 is_in_sample

Returns true if the status for this stock is B<Sample>.

=cut

sub is_in_sample {
    return shift->status_id == $FLOW_STATUS__SAMPLE__STOCK_STATUS;
}

=head2 is_in_creative

Returns true if the status for this stock is B<Creative>.

=cut

sub is_in_creative {
    return shift->status_id == $FLOW_STATUS__CREATIVE__STOCK_STATUS;
}

=head2 get_client

Returns the client associated with this quantity

=cut
sub get_client {
    my ($self) = @_;
    return $self->variant()->get_client();
}

=head2 get_sku

Returns the sku associated with this quantity

=cut
sub get_sku {
    my ($self) = @_;
    return $self->variant()->sku();
}

=head2 get_location_name

Returns the name of the location where this quantity is located

=cut
sub get_location_name {
    my ($self) = @_;
    return $self->location()->location();
}

=head2 try_to_reallocate

If the inventory has been migrated to a new PRL
and was on hold because of a stock discrepancy,
try reallocating, as it may now be pickable.

See also PutawayPrepContainer->try_to_take_shipments_off_hold

=cut

sub try_to_reallocate {
    my ( $self, $variant, $operator_id, $reason ) = validated_list(
        \@_,
        variant     => { isa => 'XTracker::Schema::Result::Public::Variant' },
        operator_id => { isa => 'Int' },
        reason      => { isa => 'Str' },
    );

    # Magic string 'MISSING' comes from PRL database table stock_adjust_reason
    my $is_stock_adjusted_to_zero
        = $self->quantity == 0 && $reason eq 'MISSING';
    xt_logger->trace("try_to_reallocate, quantity = ".$self->quantity.", reason = $reason.");

    # Have we just moved the last of some stock?
    xt_logger->trace("PRL phase = ".$self->prl_rollout_phase.", is_stock_adjusted_to_zero = $is_stock_adjusted_to_zero.");
    return unless $self->prl_rollout_phase && $is_stock_adjusted_to_zero;

    # Reallocate any orders that were put on hold because of a stock discrepancy
    #   This might result in a new allocation if the stock has just been migrated
    #   to a different PRL, and this is the last stock left in the old PRL,
    #   which we've discovered isn't actually there, and so adjusted it
    my @unique_shipments = map { $_->shipment } $variant->shipment_items
        ->get_shipment_items_with_unique_shipments_rs_contains_shipment_id_only;
    xt_logger->trace("There are ".scalar(@unique_shipments)." unique shipments for variant ".$variant->id);
    foreach my $shipment (@unique_shipments) {
        # Ignore shipments that are on-hold for other reasons
        xt_logger->debug(sub { sprintf("Is shipment on hold for reason 'Failed Allocation'? %s",
            ($shipment->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__FAILED_ALLOCATION) ? "yes" : "no")) });
        next unless $shipment->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__FAILED_ALLOCATION);

        # Take shipment off hold, it will be reallocated to the new PRL
        xt_logger->debug("Releasing shipment ".$shipment->id." from hold, which did have a stock discrepancy");
        $shipment->release_from_hold({ operator_id => $operator_id, });
    }
}

1;

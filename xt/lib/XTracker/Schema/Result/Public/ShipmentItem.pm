use utf8;
package XTracker::Schema::Result::Public::ShipmentItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_item_id_seq",
  },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "unit_price",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "tax",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "duty",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "shipment_item_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "special_order_flag",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "shipment_box_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 32 },
  "voucher_code_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "pws_ol_id",
  { data_type => "integer", is_nullable => 1 },
  "gift_from",
  { data_type => "text", is_nullable => 1 },
  "gift_to",
  { data_type => "text", is_nullable => 1 },
  "gift_message",
  { data_type => "text", is_nullable => 1 },
  "voucher_variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "qc_failure_reason",
  { data_type => "text", is_nullable => 1 },
  "container_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 255 },
  "gift_recipient_email",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "is_incomplete_pick",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "lost_at_location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "returnable_state_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "sale_flag_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "allocation_items",
  "XTracker::Schema::Result::Public::AllocationItem",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "cancelled_item",
  "XTracker::Schema::Result::Public::CancelledItem",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "container",
  "XTracker::Schema::Result::Public::Container",
  { id => "container_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "link_delivery_item__shipment_items",
  "XTracker::Schema::Result::Public::LinkDeliveryItemShipmentItem",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "link_shipment_item__price_adjustment",
  "XTracker::Schema::Result::Public::LinkShipmentItemPriceAdjustment",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "link_shipment_item__promotion",
  "XTracker::Schema::Result::Public::LinkShipmentItemPromotion",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_shipment_item__reservation_by_pids",
  "XTracker::Schema::Result::Public::LinkShipmentItemReservationByPid",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_shipment_item__reservations",
  "XTracker::Schema::Result::Public::LinkShipmentItemReservation",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "lost_at_location",
  "XTracker::Schema::Result::Public::Location",
  { id => "lost_at_location_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "renumeration_items",
  "XTracker::Schema::Result::Public::RenumerationItem",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_item_exchange_shipment_item_ids",
  "XTracker::Schema::Result::Public::ReturnItem",
  { "foreign.exchange_shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_item_shipment_item_ids",
  "XTracker::Schema::Result::Public::ReturnItem",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "returnable_state",
  "XTracker::Schema::Result::Public::ShipmentItemReturnableState",
  { id => "returnable_state_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "sale_flag",
  "XTracker::Schema::Result::Public::ShipmentItemOnSaleFlag",
  { id => "sale_flag_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_box",
  "XTracker::Schema::Result::Public::ShipmentBox",
  { id => "shipment_box_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "shipment_item_container_logs",
  "XTracker::Schema::Result::Public::ShipmentItemContainerLog",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment_item_status",
  "XTracker::Schema::Result::Public::ShipmentItemStatus",
  { id => "shipment_item_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "shipment_item_status_logs",
  "XTracker::Schema::Result::Public::ShipmentItemStatusLog",
  { "foreign.shipment_item_id" => "self.id" },
  undef,
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
__PACKAGE__->belongs_to(
  "voucher_code",
  "XTracker::Schema::Result::Voucher::Code",
  { id => "voucher_code_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "voucher_variant",
  "XTracker::Schema::Result::Voucher::Variant",
  { id => "voucher_variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->many_to_many(
  "delivery_items",
  "link_delivery_item__shipment_items",
  "delivery_item",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kgiQMcjPreFmfU+fYchAyQ

# Make sure "container_id" is transformed into instance of
# NAP::DC::Barcode::Container on the way from database
# and stringified on the way back to DB
#
use NAP::DC::Barcode::Container;
__PACKAGE__->inflate_column('container_id', {
    inflate => sub { NAP::DC::Barcode::Container->new_from_id(shift) },
    deflate => sub { shift->as_id },
});

__PACKAGE__->load_components('FilterColumn');
use XTracker::DBEncode qw( encode_db decode_db );
__PACKAGE__->filter_column($_ => {
    filter_from_storage => sub { decode_db($_[1]) },
    filter_to_storage => sub { encode_db($_[1]) },
}) for (qw( gift_message gift_recipient_email gift_to gift_from ));

=head1 NAME

XTracker::Schema::Result::Public::ShipmentItem

=head1 METHODS

=cut

use Log::Log4perl ':easy';
use XTracker::Logfile qw( xt_logger );
use XTracker::Utilities qw(number_in_list);

use XTracker::Config::Local qw( config_var );
use XTracker::SchemaHelper qw(:records);
use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :distrib_centre
    :flow_status
    :fulfilment_overview_stage
    :packing_exception_action
    :pre_order_item_status
    :pws_action
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :return_status
    :shipment_item_status
    :shipment_status
    :shipment_item_returnable_state
/;
use Carp;
use DateTime;
use XTracker::Database::Container qw( :utils );
use Moose;
with 'XTracker::Schema::Role::WithStateSignature';

use Moose::Util::TypeConstraints;
use MooseX::Params::Validate 'pos_validated_list';

use NAP::DC::Barcode::Container::Tote;
use NAP::DC::Barcode::Container::PigeonHole;
use XTracker::WebContent::StockManagement;

__PACKAGE__->has_many(
  "return_items",
  "XTracker::Schema::Result::Public::ReturnItem",
  { "foreign.shipment_item_id" => "self.id" },
);

around 'update' => sub {
    my $orig = shift;
    my $self = shift;
    my $cols = shift;

    # Set the columns so we can determine whether any of them are dirty
    # (This only updates the object, not the database)
    # Make a copy so that $cols is not messed up for the next call,
    #   when being called from a ResultSet
    my %cols_copy = %{ $cols || {} };
    my $operator_id = delete($cols_copy{operator_id}); # not a ShipmentItem column
    $self->set_inflated_columns(\%cols_copy) if %cols_copy;
    # Now the columns are dirty, when we call the original update sub ($orig below)
    # it will perform the actual update.

    # No additional actions to be taken if container_id isn't dirty
    return $self->$orig unless exists {$self->get_dirty_columns}->{container_id};

    my $schema = $self->result_source->schema;

    my $guard = $schema->txn_scope_guard;

    # Log the container update
    $schema->resultset('Public::ShipmentItemContainerLog')->create({
        shipment_item_id => $self->id,
        old_container_id => $self->get_from_storage->container_id,
        new_container_id => {$self->get_dirty_columns}->{container_id},
        operator_id      => $operator_id
                         // $schema->operator_id
                         // $APPLICATION_OPERATOR_ID,
    });

    my $return = $self->$orig;
    $guard->commit;

    return $return;
};

sub active_allocation_item {
    my $self = shift;
    return $self->search_related( 'allocation_items' )->filter_active->first;
}

=head2 return_item

Returns an uncancelled return_item for this shipment item.

=cut

sub return_item {
    my ($self) = @_;
    $self->return_items
         ->not_cancelled
         ->search({}, { order_by => {-desc => 'creation_date' } } )
         ->first;
}

=head2 update_status( $status_id, $operator_id, $packing_exception_action_id? ) : $shipment_item

Update the status of this item to $status_id and log it. Also logs the
C<$packing_exception_id> when it's passed.

=cut

sub update_status {
    my $self = shift;
    my ( $status_id, $operator_id, $packing_exception_action_id ) = pos_validated_list(\@_,
        # TODO: Can't get 'messages' to work for subtype, so the error message
        # is a little ugly :( Feel free to try and make it work if you have a
        # little time on your hands
        {
            isa => subtype({
                as => 'Int',
                where => sub {
                    my $val = $_;
                    scalar grep { $val == $_ } @SHIPMENT_ITEM_STATUS_VALUES;
                },
            }),
        },
        { isa => 'Int', },
        {
            isa => subtype({
                as => 'Int',
                where => sub {
                    my $val = $_;
                    scalar grep { $val == $_ } @PACKING_EXCEPTION_ACTION_VALUES;
                },
            }),
            optional => 1,
        },
    );

    # Do nothing if there's no status change
    return $self if $self->shipment_item_status_id == $status_id;

    $self->result_source->schema->txn_do( sub {
        $self->update( { shipment_item_status_id => $status_id } );

        $self->shipment_item_status_logs->create({
            shipment_item_id            => $self->id,
            shipment_item_status_id     => $status_id,
            operator_id                 => $operator_id,
            packing_exception_action_id => $packing_exception_action_id,
        });
    });
    return $self;
}

=head2 is_new

Check if the shipment item's status is 'New'.

=cut

sub is_new {
    return shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__NEW;
}

=head2 is_selected

Check if the shipment item's status is B<Selected>.

=cut

sub is_selected {
    return shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__SELECTED;
}

=head2 is_cancelled

check if it's cancelled

=cut

sub is_cancelled {
    return shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCELLED;
}

=head2 is_cancel_pending

check if it's cancel_pending

=cut

sub is_cancel_pending {
    return shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
}

=head2 is_returnable

Return true if the item is returnable

=cut

sub is_returnable {
    return shift->returnable_state_id == $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
}

=head2 is_not_returnable

Return true if the item is not returnable

=cut

sub is_not_returnable {
    return shift->returnable_state_id == $SHIPMENT_ITEM_RETURNABLE_STATE__NO;
}

=head2 is_cc_only

Return true if the item has cc_only returnable state

=cut

sub is_customer_care_returnable_only {
    return shift->returnable_state_id == $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY;
}

=head2 display_on_returns_proforma

Return true if the item is to appear on the returns proforma

=cut

sub display_on_returns_proforma {
    my $self = shift;
    return $self->is_returnable || $self->get_channel->is_fulfilment_only;
}

=head2 is_picked

Returns true if the item has a status of I<Picked>.

=cut

sub is_picked {
    return shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PICKED;
}

=head2 is_packed

Returns true if the item has a status of I<Packed>

=cut

sub is_packed {
    return shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKED;
}

=head2 is_returnable_on_pws

    $boolean = $self->is_returnable_on_pws;

Will use the value of the 'returnable_on_pws' field on
the 'shipment_item_returnable_state' table that this
records 'returnable_state_id' value points to.

At the time of writing would return:
    Yes     - 1
    No      - 0
    CC Only - 0

=cut

sub is_returnable_on_pws {
    my $self    = shift;

    return $self->returnable_state->returnable_on_pws;
}

=head2 set_returned( $operator_id )

Sets the status of a shipment item to B<Returned>.

=cut

sub set_returned {
    my ( $self, $operator_id ) = @_;
    return $self->update_status($SHIPMENT_ITEM_STATUS__RETURNED, $operator_id);
}

=head2 set_dispatched( $operator_id )

Sets the status of an item to B<Dispatched>.

=cut

sub set_dispatched {
    my ( $self, $operator_id ) = @_;
    return $self->update_status($SHIPMENT_ITEM_STATUS__DISPATCHED, $operator_id);
}

=head2 set_cancelled( $operator_id )

Sets the status of a shipment item to B<Cancelled>.

=head3 NOTE

The calling function is still responsible for updating web stock as appropriate.

=cut

sub set_cancelled {
    my ($self, $operator_id) = @_;
    return $self->update_status($SHIPMENT_ITEM_STATUS__CANCELLED, $operator_id);
}

=head2 set_cancel_pending

Set the items's status to B<Cancel Pending>.

=cut

sub set_cancel_pending {
    my ( $self, $operator_id ) = @_;
    return $self->update_status($SHIPMENT_ITEM_STATUS__CANCEL_PENDING, $operator_id);
}

=head2 can_cancel

Returns a true value if this shipment item can be cancelled.

=cut

sub can_cancel {
    my ( $self ) = @_;
    return $self->is_pre_dispatch;
}

=head2 cancel( \%args )

Cancel the shipment item as well as updating the website.

Required arguments are:

=over

=item operator_id

=item customer_issue_type_id

=back

The following arguments are required if the cancellation is being completed and
you might be updating the website:

=item stock_manager

=back

The following arguments are optional:

=over

=item do_pws_update

The default behaviour is to update the public website (i.e. the flag is set to
true), however you can set this to false if you want to skip any updates. This
is always false for virtual vouchers. You might want this if you are cancelling
due to a stock discrepancy.

=item pws_action_id

Defaults to B<Cancellation>.

=item notes

Defaults to I<Cancel item $shipment_item_id>.

=back

=cut

sub cancel {
    my $self = shift;

    !defined $_[0]{$_} && croak "You must set a value for $_"
        for qw/operator_id customer_issue_type_id/;

    my ( $operator_id, $customer_issue_type_id, $pws_action_id, $notes, $stock_manager, $do_pws_update, $no_allocate )
        = @{$_[0]}{qw/operator_id customer_issue_type_id pws_action_id notes stock_manager do_pws_update no_allocate/};

    return if $self->is_cancelled || $self->is_cancel_pending;

    croak sprintf(
        'You can only cancel items that have not been dispatched yet, you are trying to cancel an item that is %s',
        $self->shipment_item_status->status
    ) unless $self->can_cancel;

    $self->result_source->schema->txn_do(sub{
        # We can always do this and when the item is not a voucher it's a no-op
        $self->unassign_and_deactivate_voucher_code;
        $self->create_related('cancelled_item',
            { customer_issue_type_id => $customer_issue_type_id }
        );
        # Decide whether we need to update status to cancel pending or cancelled
        if ( $self->_do_cancel_pending ) {
            $self->set_cancel_pending( $operator_id );
        }
        else {
            $self->_complete_cancellation({
                operator_id => $operator_id,
                pws_action_id => $pws_action_id,
                notes => $notes,
                stock_manager => $stock_manager,
                do_pws_update => $do_pws_update // 1,
            });
        }
    });

    # Send an allocation unless the caller has told us not to
    $self->shipment->allocate({ operator_id => $operator_id }) unless $no_allocate;

    return $self;
}

sub _do_cancel_pending {
    my $self = shift;
    return !$self->is_virtual_voucher
        && ( $self->has_been_picked || $self->is_being_picked );
}

=head2 complete_cancellation( \%args )

This method is untried and untested, here as a placeholder following WHM-1437.
Use at your own peril, or even better make sure it works before using it in
production!

=cut

sub complete_cancellation {
    my ( $self, $args ) = @_;

    croak q{You can only cancel items that are in 'Cancel Pending'}
        unless $self->is_cancel_pending;

    $self->_complete_cancellation({
        map { $_ => $args->{$_} } qw/
            operator_id pws_action_id notes stock_manager do_pws_update
        /,
    });

    return $self;
}

# Note that this method will not check the item's current status - only call
# this if you know what you're doing
sub _complete_cancellation {
    my $self = shift;

    croak 'operator_id is required' unless $_[0]{operator_id};

    !$self->is_virtual_voucher && !defined $_[0]{$_} && croak "$_ is required"
        for 'do_pws_update';

    my ( $operator_id, $pws_action_id, $notes, $stock_manager, $do_pws_update )
        = @{$_[0]}{qw/operator_id pws_action_id notes stock_manager do_pws_update/};

    # Never update the website for virtual vouchers
    $do_pws_update = $self->is_virtual_voucher ? 0 : $do_pws_update;

    $do_pws_update && !defined $_[0]{$_} && croak "$_ is required"
        for qw/pws_action_id stock_manager/;

    $self->result_source->schema->txn_do(sub{
        $self->set_cancelled( $operator_id );

        return unless $do_pws_update;
        $self->get_true_variant->update_pws_quantity({
            delta => 1,
            action => $pws_action_id || $PWS_ACTION__CANCELLATION,
            operator_id => $operator_id,
            notes => $notes || 'Cancel item ' . $self->id,
            stock_manager => $stock_manager,
        });
    });
    return $self;
}

=head2 set_lost( $operator_id, [$location_id] )

Change shipment item's status to B<Lost>. You can pass an optional second
argument C<$location_id> if the item was lost at a specific location.

=cut

sub set_lost {
    my ( $self, $operator_id, $location_id ) = @_;
    $self->result_source->schema->txn_do(sub{
        $self->update_status($SHIPMENT_ITEM_STATUS__LOST, $operator_id);
        $self->update({lost_at_location_id => $location_id});
    });
    return $self;
}

=head2 found( $operator_id )

Mark a shipment item as found. Note that this implementation currently only
works for sample shipments (i.e. shipments with a class of I<Sample>, I<Press>
or I<Transfer Shipment>). As these only have one item, this method will
automatically update the parent shipment's status too.

=head3 NOTE

Maybe we should find the shipment object and automatically find its items?

=cut

# Ensure we only use this for sample shipments
# Check if we have a quantity at the given location
# - Yes: increase quantity by 1
# - No: Create quantity of 1
# Log
# Update shipment item
# Update shipment
sub found {
    my ( $self, $operator_id ) = @_;

    my $shipment = $self->shipment->discard_changes;

    # Make sure we only run this for sample shipments
    croak q{This method is currently only implemented for sample shipments}
        unless $shipment->is_sample_shipment;

    # We should hopefully always know where an item was lost, however instead
    # of dying in the next call let's default to returning the item to the
    # Sample Room
    my $location = $self->lost_at_location
                || $self->result_source
                        ->schema
                        ->resultset('Public::Location')
                        ->find({ location => 'Sample Room' });

    # Determine the first allowed status for this location (sample
    # locations should only have one anyway)
    my $location_allowed_status_id = $location->location_allowed_statuses->first->status_id;

    my $return = $shipment->returns->first;
    my $new_si_status = $return
                      ? $SHIPMENT_ITEM_STATUS__RETURN_PENDING
                      : $SHIPMENT_ITEM_STATUS__DISPATCHED;
    # Add/update the quantity and update the shipment item/shipment rows
    $self->result_source->schema->txn_do(sub{
        # Check whether we need to create a new quantity or we can add to an
        # existing one
        my $quantity = $location->search_related('quantities', {
            variant_id => $self->variant_id,
            channel_id => $shipment->stock_transfer->channel_id,
            status_id  => $location_allowed_status_id,
        })->slice(0, 0)->single;
        $quantity ||= $location->create_related('quantities', {
            variant_id => $self->variant_id,
            channel_id => $shipment->stock_transfer->channel_id,
            quantity => 0,
            status_id => $location_allowed_status_id,
        });
        $quantity->update_and_log_sample({
            delta => 1,
            operator_id => $operator_id,
            notes => '',
        });
        # Item is no longer lost, so clear 'lost at' location
        $self->update({ lost_at_location_id => undef });
        # And update row statuses
        $self->update_status($new_si_status, $operator_id);
        $shipment->update_status($SHIPMENT_STATUS__DISPATCHED, $operator_id);
        $return->set_awaiting_return( $operator_id ) if $return;
    });
    return $self;
}

=head2 set_selected( $operator_id )

Update the shipment's status to B<Selected>.

=cut

sub set_selected {
    my ($self, $operator_id) = @_;

    # don't update Virtual Vouchers
    return if $self->is_virtual_voucher;
    # don't update unless it is in NEW state
    return unless $self->is_new;

    $self->update_status($SHIPMENT_ITEM_STATUS__SELECTED, $operator_id);
}

=head2 validate_pick_into( $container_id )

Calls L<XTracker::Schema::Result::Public::Container::validate_pick_into> for
this shipment item.

=cut

sub validate_pick_into {
    my ($self, $container_id) = @_;

    # Some container validation (next line throws an exception if $container_id is invalid)
    $container_id = NAP::DC::Barcode::Container::Tote->new_from_id($container_id);

    my $container=get_container_by_id( $self->result_source->schema, $container_id );

    return $container->validate_pick_into( { shipment_item => $self } );
}

=head2 validate_pick_into( $container_id )

Calls
L<XTracker::Schema::Result::Public::Container::validate_packing_exception_into> for
this shipment item.

=cut

# TODO: Is this unused? Consider deprecating it.
sub validate_packing_exception_into {
    my ($self, $container_id) = @_;

    $container_id = NAP::DC::Barcode::Container->new_from_id($container_id);

    # Make sure container ID is any kind of Tote or PigeonHole
    die 'Invalid container name. Container names must start with the letter "M" or "P"'
        unless ($container_id->is_type("any_tote", "pigeon_hole"));

    my $container = get_container_by_id(
        $self->result_source->schema,
        $container_id,
    );

    return $container->validate_packing_exception_into({
        shipment_item => $self,
    });
}

=head2 pick_into( $container_id, $operator_id, [\%options] )

Picks this item into the given container.

=cut

sub pick_into {
    my ($self, $container_id, $operator_id, $options) = @_;

    my $container=get_container_by_id($self->result_source->schema, $container_id );

    $container->add_picked_item( { shipment_item => $self,
                                   dont_validate => $options->{dont_validate} });

    # updates status and log
    my $status = $options->{'status'} || $SHIPMENT_ITEM_STATUS__PICKED;
    $self->update_status($status, $operator_id);
}

=head2 packing_exception_into

Adds this packing exception item into the given container.

=cut

sub packing_exception_into {
    my ($self, $container_id, $operator_id, $options) = @_;

    my $container=get_container_by_id($self->result_source->schema, $container_id );

    $container->add_packing_exception_item( { shipment_item => $self,
                                              dont_validate => $options->{dont_validate} });

    return $self;
}

=head2 orphan_item_into

Place canceled shipment_items into PEO totes

=cut

sub orphan_item_into {
    my ($self, $container_id, $options) = @_;

    my $container=get_container_by_id($self->result_source->schema, $container_id );

    $container->add_orphan_item( { shipment_item => $self,
                                   dont_validate => $options->{dont_validate} });
    return $self;
}

=head2 unpick

Unpick this item (what does this mean?)

=cut

sub unpick {
    my ($self) = @_;

    return unless $self->container;

    $self->container->remove_item( { shipment_item => $self } );
}

=head2 product_id

Decide if product or voucher and return the id appropriately

=cut

sub product_id {
    my ($self) = @_;

    return ( defined $self->variant_id
           ? $self->variant->product_id
           : $self->voucher_variant->product_id
    );
}

=head2 product

Decide if product or voucher and return the object appropriately

=cut

sub product {
    my ($self) = @_;

    # decide if product or voucher and return appropriately
    return (
                defined $self->variant_id
                ? $self->variant->product
                : $self->voucher_variant->product
           );
}

=head2 has_been_picked

Return a true value if the item has been picked (does the opposite of
L<is_pre_picked>)

=cut

sub has_been_picked { return !shift->is_pre_picked; }

=head2 is_pre_picked

Returns true if the item is B<New> or B<Selected>.

=cut

sub is_pre_picked {
    my $self = shift;
    return $self->is_new || $self->is_selected;
}

=head2 is_pre_picking_commenced

Returns a true value if we have a status of B<New> or B<Selected> and the
B<is_picking_commenced> flag is false.

=cut

sub is_pre_picking_commenced {
    my $self = shift;
    return $self->is_new || ($self->is_selected && !$self->shipment->is_picking_commenced);
}

=head2 is_being_picked() : Bool

Returns a true value if picking has commenced for this item but is not
completed yet.

=cut

sub is_being_picked {
    my $self = shift;

    # This logic is slightly different if we have allocation items (i.e. we
    # have a prl) as the is_incomplete_pick flag isn't set - this breaks the
    # logic for short picks
    if ( $self->allocation_items->count ) {
        my $allocation_item = $self->active_allocation_item or return 0;
        return $allocation_item->is_picking;
    }

    return $self->is_selected
        && $self->shipment->is_picking_commenced
        && !$self->is_incomplete_pick;
}

=head2 is_pre_dispatch

Returns true if the item is B<New>, B<Selected>, B<Picked>, B<Packing
Exception> or B<Packed>.

=cut

sub is_pre_dispatch {
    number_in_list($_[0]->shipment_item_status_id,
                   $SHIPMENT_ITEM_STATUS__NEW,
                   $SHIPMENT_ITEM_STATUS__SELECTED,
                   $SHIPMENT_ITEM_STATUS__PICKED,
                   $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                   $SHIPMENT_ITEM_STATUS__PACKED,
               );
}

=head2 date_dispatched

Return a DateTime object representing the date the item was dispatched.

=cut

sub date_dispatched {
    my ($self) = @_;

    return if $self->is_pre_dispatch;

    my $log = $self->shipment_item_status_logs->search(
        { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED }
    )->first;

    # Sanity check - there should be one of these since the status says we're
    # dispatched
    Carp::confess sprintf(
        "Shipment item (%d) has a status of  %s, should be >=dispatched, but no log",
        $self->id, $self->shipment_item_status->status)
            unless $log;

    return $log->date;
}

=head is_returned

Returns a true value if the status for this item is 'Returned'.

=cut

sub is_returned { shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__RETURNED };

=head2 is_lost

Returns a true value if the status for this item is B<Lost>.

=cut

sub is_lost { shift->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__LOST; }

=head2 website_status

The status to report to the website. This is different from just the status
because the item is marked as return complete once it passes QC, but it
shouldn't go to completed on the website until the refund or the exchange has
been actioned. (Ugh, i just used the word 'actioned' -- kill me now).

=cut

sub website_status {
    my ($self) = @_;

    my $status = $self->shipment_item_status;

    return $status unless $self->is_returned;

    my $return_item = $self->return_item;

    if (!$return_item) {
        # sanity check
        Carp::confess "Shipment item @{[$self->id]} has status of 'Returned' but no return_item!";
    }


    my $completed = 1;
    if ($return_item->is_exchange) {
        # Exchange shipment, the return is only complete once the exchange has been dispatched
        my $exch_s_i = $return_item->exchange_shipment_item;
        $completed = $exch_s_i && $exch_s_i->date_dispatched;
    }
    else {
        # Refund, complete once the refund has been processed. Refund is a
        # reunmeration against the shipment
        my $renum = $return_item->return
                                ->renumerations
                                ->not_cancelled
                                ->for_returns
                                ->first;
        if (!$renum) {
            # TODO: Fix the Test::..::Data->create_rma to create a valid renumeration record!
            Carp::cluck "Shipment item @{[$self->id]} has status of 'Returned', is a refund, but we can't find the renumeration record!"
              unless $ENV{NO_AMQ_WARNINGS};
            $completed = 0;
        }
        else {
            $completed = $renum->is_completed;
        }
    }

    if (!$completed) {
        $status = $self->result_source
                       ->schema
                       ->resultset('Public::ShipmentItemStatus')
                       ->find($SHIPMENT_ITEM_STATUS__RETURN_RECEIVED);
    }
    return $status;
}

=head2 last_location

Return the location with most stock for this item's variant.

=cut

sub last_location {
    my ($self) = @_;
    my $schema = $self->result_source->schema;

    # exact match with a location currently being used
    my $locations = undef;
    my $resultset = $schema->resultset('Public::Variant')
        ->search({
            'me.id' => $self->variant_id,
        })->search_related_rs('quantities');

    if ($resultset and $resultset->count) {
        # loop through the locations of where existing stock is and use
        # the one with most stock
        # taken from template - stocktracker/inventory/overview.tt
        my $max_qty = undef;
        while (my $qty = $resultset->next) {
            if (not defined $max_qty or $qty->quantity > $max_qty->quantity) {
                $max_qty = $qty;
            }
        }

        if (defined $max_qty) {
            return $max_qty->location->location;
        }
    }

    # we could potentially do another search based on above and try match
    # on just product_id and then maybe suggest location of similar sku
    # - this maybe confusing




    $locations = $schema->resultset('Public::StockCountVariant')
        ->search(
        {
            variant_id => $self->variant_id,
        },
        {
            'prefetch'  => [qw/location/],
        }
    );

    if ($locations and $locations->count > 0) {
        return $locations->first->location->location;
    }

    $locations = $schema->resultset('Public::LogLocation')
        ->search(
        {
            variant_id => $self->variant_id,
        },
        {
            'order_by'  => 'date DESC',
        }
    );

    if ($locations and $locations->count > 0) {
        return $locations->first->location->location;
    }

    return;
}

=head2 get_true_variant

Returns the variant or voucher variant, depending what this object references

=cut

sub get_true_variant {
    return $_[0]->variant || $_[0]->voucher_variant;
}

=head2 is_voucher

Returns true if the shipment item references a voucher.

=cut

sub is_voucher {
    return defined shift->voucher_variant_id;
}

=head2 is_physical_voucher() : Bool

Return true if a shipment item for a Physical Voucher

=cut

sub is_physical_voucher {
    my $self    = shift;

    return undef unless $self->voucher_variant_id;
    return $self->voucher_variant->product->is_physical;
}

=head2 is_boxed

Return true if a shipment item is already boxed

=cut

sub is_boxed {
    my $self = shift;

    return ($self->is_packed && $self->shipment_box_id);
}


=head2 is_virtual_voucher

Return true if a shipment item for a Virtual Voucher

=cut

sub is_virtual_voucher {
    my $self    = shift;

    return undef unless $self->voucher_variant_id;
    return !$self->is_physical_voucher;
}

=head2 refund_invoice_total

This returns the total Unit Price, Tax & Duty that has been refunded so far
for this shipment item. It should ignore cancelled invoices. This is used by
XT::Domain::Returns::Calc to deduct the total amount that can be refunded for
each shipment item when calculating the refund value.

=cut

sub refund_invoice_total {
    my $self    = shift;

    my ( $price, $tax, $duty )  = ( 0, 0, 0 );

    # search all renumeration items for this shipment item
    my $renums  = $self->renumeration_items->search(
                                {
                                    'renumeration.renumeration_status_id' => { '!=' => $RENUMERATION_STATUS__CANCELLED },
                                    'renumeration.renumeration_class_id'  => { '!=' => $RENUMERATION_CLASS__ORDER },
                                    'renumeration.renumeration_type_id'   => [
                                                                                $RENUMERATION_TYPE__STORE_CREDIT,
                                                                                $RENUMERATION_TYPE__CARD_REFUND
                                                                           ],
                                },
                                {
                                    join    => 'renumeration',
                                }
                            );

    # get the totals for each bit
    $price  = $renums->get_column('unit_price')->sum || 0;
    $tax    = $renums->get_column('tax')->sum || 0;
    $duty   = $renums->get_column('duty')->sum || 0;

    return ( $price, $tax, $duty );
}

=head2 unassign_and_deactivate_voucher_code

This will clear the C<voucher_code_id> and de-activate the Voucher Code.

=cut

sub unassign_and_deactivate_voucher_code {
    my $self    = shift;

    # no voucher code then nothing to do
    return      if ( !defined $self->voucher_code_id );

    my $code    = $self->voucher_code;
    $code->deactivate_code;
    $self->update( { voucher_code_id => undef } );

    return;
}

=head2 voucher_usage

A convenience sub that calls voucher_usage in ResultSet::Orders::Tender with
this object's C<voucher_code_id>, or return undef if it doesn't have one.

=head3 NOTE

This is the DBIC version of
XTracker::Database::Shipment::get_shipment_item_voucher_usage.

=cut

sub voucher_usage {
    my ( $self ) = @_;

    return unless $self->voucher_code_id;

    return $self->result_source
                ->schema
                ->resultset('Orders::Tender')
                ->voucher_usage( $self->voucher_code_id );
}

=head2 get_channel

Helper to get the channel associated with a shipment_item

=cut

sub get_channel {
    my ( $self ) = @_;

    return $self->shipment->get_channel;
}

=head2 is_qc_failed

Helper to confirm that this is a QC-failed item

=cut

sub is_qc_failed {
    my $self = shift;

    # If the item's status is PE, then it's definitely failed
    return 1 if
        $self->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;

    # If it's cancel-pending and there's related QC text, it's also failed
    return 1 if
        $self->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING &&
        $self->qc_failure_reason;

    # Otherwise, it's fine
    return 0;
}

=head2 is_missing

Helper to confirm that this is a missing item

=cut

sub is_missing {
    my $self = shift;

    return $self->is_qc_failed && !(defined $self->container_id);
}

=head2 get_sku

Return the sku for this item's variant.

=cut

sub get_sku {
    return shift->get_true_variant->sku;
}

=head2 get_product_id

Returns the product_id for this variant. A different way of obtaining the same
result as C<< $self->product_id >>.

=cut

sub get_product_id {
    return shift->get_true_variant->product_id;
}

=head2 packing_exception_operator

Return the operator who raised the packing exception.

=cut

sub packing_exception_operator {
    my ($self) = @_;

    my ($log_entry) =
        $self->search_related('shipment_item_status_logs',{
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
        },{
            order_by => { -desc => 'date' },
            prefetch => 'operator',
        })->slice(0,0)->single;
    if ($log_entry) {
        return $log_entry->operator;
    }
    return;
}

=head2 move_stock_to_location($location_row, $flow_status_id, $operator_row) :

Move the Variant of the ShipmentItem into $location_row, logging it
under the $operator_row user.

=cut

sub move_stock_to_location {
    my ($self, $location_row, $flow_status_id, $operator_row) = @_;

    my $schema = $self->result_source->schema;
    my $quantity_rs = $schema->resultset( "Public::Quantity" );
    $quantity_rs->move_stock({
        variant  => $self->get_true_variant,
        channel  => $self->get_channel,
        quantity => 1,
        from     => undef,
        to       => {
            location => $location_row,
            status   => $flow_status_id,
        },
        log_location_as => $operator_row,
    });
}


=head2 cancel_and_move_stock_to_iws_location_and_notify_pws($operator_id) :

If IWS rollout_phase, cancel the ShipmentItem, notify the web site and
move the stock to back to the IWS location.

--- alternate docs from a previous age ---

Phase 1, we need to change its status and add to INVAR. We then need
to do all the inventory crap that's in SetCancelPutAway.pm.
XXX all this only works for *orders*
transfers & samples should really not show up here… maybe. we hope.

=cut

sub cancel_and_move_stock_to_iws_location_and_notify_pws {
    my ($self, $operator_id) = @_;
    return unless ( config_var('IWS', 'rollout_phase') );

    my $notes = $self->cancel_and_move_stock_to_iws_location($operator_id);
    $self->notify_pws_of_cancellation($operator_id, $notes);

    return;
}

=head2 cancel_and_move_stock_to_iws_location( $operator_id )

Uhh... this seems to cancel stock, update the item's status to B<Cancelled>
and return notes for the cancelled item.

=cut

sub cancel_and_move_stock_to_iws_location {
    my ($self,$operator_id) = @_;

    return unless $self->is_cancel_pending;

    my $schema      = $self->result_source->schema;
    my $destination = $schema->resultset('Public::Location')->get_iws_location;

    my $notes;
    $schema->txn_do(
        sub {
            $self->move_stock_to_location(
                $destination,
                $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                $operator_id,
            );

            $self->set_cancelled( $operator_id );

            my $ci = $self->cancelled_item;
            die "Cannot find Cancelled Item for shipment_item_id - ".$self->id
                unless $ci;
            $notes = $ci->notes;

            # (Not strictly needed, it's already removed, but keeping
            # it here after refactoring)
            $self->update({ container_id => undef });
        });

    return $notes;
}

=head2 move_stock_to_cancelled_location($operator_row) : $cancelled_location_row

Move the Variant of the ShipmentItem into the Cancelled-to-Putaway
Location, logging it under the $operator_row user.

=cut

sub move_stock_to_cancelled_location {
    my ($self, $operator_row) = @_;

    my $location_rs = $self->result_source->schema->resultset("Public::Location");
    my $cancelled_location_row = $location_rs->get_cancelled_location();

    $self->move_stock_to_location(
        $cancelled_location_row,
        $FLOW_STATUS__IN_TRANSIT_TO_PRL__STOCK_STATUS,
        $operator_row,
    );

    return $cancelled_location_row;
}

sub notify_pws_of_cancellation {
    my ($self, $operator_id, $notes) = @_;

    my $schema = $self->result_source->schema;
    my $stock_manager
        = XTracker::WebContent::StockManagement->new_stock_manager({
            schema     => $schema,
            channel_id => $self->get_channel->id,
        });

    $stock_manager->stock_update(
        quantity_change => 1,
        variant_id      => $self->get_true_variant->id,
        pws_action_id   => $PWS_ACTION__CANCELLATION,
        operator_id     => $operator_id,
        notes           => $notes,
    );

    $stock_manager->commit();
    $stock_manager->disconnect();

}

=head2 relationships_for_signature

Always returns 'container'. Don't know what this does... look at
XTracker::Schema::Role::WithStateSignature.

=cut

sub relationships_for_signature {
    return 'container';
}

=head2 is_discounted

Returns true if the item was bought at a discount.

=cut

sub is_discounted {
    my($self) = @_;

    # if it has a price adjustment then its considered on sale/discount/whatever
    if ($self->link_shipment_item__price_adjustment) {
        return 1;
    }

    return 0;
}

=head2 purchase_price

The price the customer paid for the item. Sum of unit_price + tax + duty

=cut

sub purchase_price {
    my($self) = @_;
    my $unit_price = $self->unit_price || 0;
    my $tax = $self->tax || 0;
    my $duty = $self->duty || 0;

    return $unit_price + $tax + $duty;
}

=head2 price_adjustment

Returns the first related price adjustment object that applies to this variant.

=cut

sub price_adjustment {
    my ( $self ) = @_;

    my $schema = $self->result_source->schema;

    my $price_adjustment_rs = $schema->resultset(
        'Public::PriceAdjustment'
    );

    my $formatted_date = $schema->format_datetime($self->shipment->date);

    return $price_adjustment_rs->search({
        product_id  => $self->variant->product_id,
        date_start  => { '<' => $formatted_date },
        date_finish => { '>' => $formatted_date }
    })->first;
}

=head2 has_price_adjustment

Check whether a shipment item has any price adjustments.

=head3 NOTE

This appears to be an alias for C<< $self->price_adjustment >>, though it's
named as if it's trying to be an alias for C<< $self->is_discounted >>. We
should probably delete it.

=cut

sub has_price_adjustment {
    my ( $self ) = @_;

    return $self->price_adjustment;
}

sub set_special_order_flag {
    my $self = shift;

    return $self->update({special_order_flag => 1});
}

sub check_for_and_assign_reservation {
    my $self = shift;

    my $order = $self->shipment->order;

    return if( !$order );

    my $reservation;

    my $is_pre_order = $order->has_preorder;

    if ( $is_pre_order ) {
        $reservation = $self->get_preorder_reservation_to_link_to;
    } else {
        $reservation = $self->get_reservation_to_link_to;
    }

    if ( $reservation ) {

        # set reservation purchased
        $reservation->set_purchased;

        # set special order flag on this item
        $self->set_special_order_flag;

        # link to reservation
        $self->link_with_reservation( $reservation );

        return;
    }

    #return, if reservaton is for pre_order
    return if $is_pre_order;

    # look for reservation link by pid
    $reservation = $self->get_reservation_to_link_to_by_pid;

    if( $reservation ) {

        # set special order flag on this item
        $self->set_special_order_flag;

        # link to reservation_by_pid
        $self->link_with_reservation_by_pid( $reservation );

    }

    return;
}

=head2 get_reservation_to_link_to

Returns a reservation for this shipment item, for the customer of this order,
if exists. Excludes any Reservations linked to Pre-Orders.

=cut

sub get_reservation_to_link_to {
    my $self = shift;

    if ( $self->is_linked_to_reservation ) {
        # already linked so don't return anything
        return;
    }

    # check in case it's a Sample Shipment
    my $order   = $self->shipment->order;

    return if( !$order );

    return $order->customer
        ->reservations
        ->not_for_pre_order
        ->uploaded
        ->by_variant_id( $self->variant_id )
        ->search( {}, { order_by => 'me.ordering_id' } )
        ->first;
}

=head2 get_reservation_to_link_to_by_pid

Returns a reservation for this shipment item, it tries to match at pid level.
We first match the uploaded reservations if not then look through the cancelled
ones. Also exclude any Reservations linked to Pre-Orders.

=cut

sub get_reservation_to_link_to_by_pid {
    my $self = shift;

    my $product_id = $self->get_product_id;

    if( $self->is_linked_to_reservation ) {
        # already linked, hence do not return anything
        return;
    }

    my $order   = $self->shipment->order;

    return unless $order;

    # check for uploaded reservations
    my $reservation  = $order->customer
                       ->reservations
                       ->not_for_pre_order
                       ->uploaded
                       ->by_pid( $product_id )
                       ->created_before_or_on( $order->date )
                       ->search( {},{ order_by => [ 'date_created','id' ] } )
                       ->first;

    return $reservation if $reservation;

    # get me all cancelled or purchased reservation
    return $order->customer
           ->reservations
           ->not_for_pre_order
           ->cancelled_or_purchased
           ->by_pid( $product_id )
           ->created_before_or_on( $order->date )
           ->commission_cut_off_date_from( $order->date )
           ->search( {}, { order_by => [ 'date_created', 'id'] } )
           ->first;
}

=head2 is_linked_to_reservation

Returns true if shipment_item is linked to reservation else return false.

=cut

sub is_linked_to_reservation {
    my $self = shift;

    if( $self->link_shipment_item__reservations->first ) {
        return 1;
    } elsif( $self->link_shipment_item__reservation_by_pids->first ) {
        return 1;
    } else {
        return 0;
    }

}

=head2 old_container_id

Returns the id of the container this item went missing from, if this has been
recorded in qc_failure_reason

=cut

sub old_container_id {
    my $self = shift;
    return unless ($self->qc_failure_reason);
    my $old_container_id = ($self->qc_failure_reason =~ /missing\sfrom\s(\w+\d+)/)[0];

    # make sure that result container ID is object of NAP::DC::Barcode::Container
    $old_container_id = NAP::DC::Barcode::Container->new_from_id($old_container_id)
        if $old_container_id;

    return $old_container_id;
}

=head2 selected_outside_of_shipment

Returns a resultset of the shipment items have been selected for this item's
variant outside of its shipment.

=cut

sub selected_outside_of_shipment {
    my ( $self ) = @_;
    return $self->get_true_variant->selected->search(
        { 'shipment_id' => { q{!=} => $self->shipment_id } }
    );
}

=head2 sample_selected_outside_of_shipment

Returns a resultset of shipment items that are part of a shipment with a
status of I<Transfer Shipment> and have been selected for this item's variant
outside of its shipment.

=cut

sub sample_selected_outside_of_shipment {
    my ( $self ) = @_;
    return $self->get_true_variant->selected_for_sample->search(
        { 'shipment_id' => { q{!=} => $self->shipment_id } }
    );
}

=head2 get_preorder_reservation_to_link_to

Returns a Reservation DBIx object for this Shipment Item that
is linked to a Pre-Order. Excludes all Normal Reservations.

=cut

sub get_preorder_reservation_to_link_to {
    my $self = shift;

    if ( $self->link_shipment_item__reservations->first ) {
        # already linked so don't return anything
        return;
    }

    # check in case it's a Sample Shipment
    my $order   = $self->shipment->order;
    return      if ( !$order );

    # check in case it's NOT a Pre-Order Order
    my $pre_order   = $order->get_preorder;
    return      if ( !$pre_order );

    my $reservation = $pre_order->pre_order_items
        ->search( {
            'me.variant_id'                 => $self->variant_id,
            'me.pre_order_item_status_id'   => $PRE_ORDER_ITEM_STATUS__EXPORTED,
        }, { order_by => 'me.id' } )
        ->search_related('reservation')->uploaded->first;

    return $reservation;
}

=head2 link_with_reservation

Creates a link between Shipment Item and Reservation tables

=cut

sub link_with_reservation {
    my ($self, $reservation) = @_;

    return $self->create_related('link_shipment_item__reservations', {
        reservation_id => $reservation->id
    });
}


=head2 link_with_reservation_by_pid

Creates a link between Shipment Item and Reservation tables in
'link_shipment_item__reservations_by_pid' table

=cut

sub link_with_reservation_by_pid {
    my ( $self, $reservation ) = @_;

    return $self->create_related( 'link_shipment_item__reservation_by_pids', {
        reservation_id => $reservation->id
    });

}

=head2 get_client

Return the client associated with this shipment item

=cut

sub get_client {
    my ($self) = @_;
    return $self->get_true_variant()->get_client();
}

=head2 get_prl

Return the PRL row related to the shipment item

=cut

sub get_prl {
    my ($self) = @_;
    my $allocation_item_row = $self->active_allocation_item or return undef;
    return $allocation_item_row->allocation->prl;
}

=head2 is_awaiting_labelling

Returns whether the shipment item is awaiting labelling

=cut

sub is_awaiting_labelling {
    my ($self) = @_;
    return (config_var('Fulfilment', 'labelling_subsection'))
           && $self->shipment_item_status->fulfilment_overview_stage_id == $FULFILMENT_OVERVIEW_STAGE__AWAITING_DISPATCH
           && defined $self->shipment_box  && !$self->shipment_box->is_labelled;
}

1;

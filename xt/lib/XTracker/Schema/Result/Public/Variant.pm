use utf8;
package XTracker::Schema::Result::Public::Variant;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.variant");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "variant_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "size_id_old",
  { data_type => "integer", is_nullable => 1 },
  "nap_size_id",
  { data_type => "integer", is_nullable => 1 },
  "legacy_sku",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "size_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "designer_size_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "std_size_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "vtype",
  { data_type => "text", default_value => "product", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("variant_unique_sku", ["product_id", "size_id", "type_id"]);
__PACKAGE__->has_many(
  "channel_transfer_picks",
  "XTracker::Schema::Result::Public::ChannelTransferPick",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfer_putaways",
  "XTracker::Schema::Result::Public::ChannelTransferPutaway",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "designer_size",
  "XTracker::Schema::Result::Public::Size",
  { id => "designer_size_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "log_putaway_discrepancies",
  "XTracker::Schema::Result::Public::LogPutawayDiscrepancy",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_pws_reservation_corrections",
  "XTracker::Schema::Result::Public::LogPwsReservationCorrection",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_rtv_stocks",
  "XTracker::Schema::Result::Public::LogRtvStock",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orphan_items",
  "XTracker::Schema::Result::Public::OrphanItem",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_items",
  "XTracker::Schema::Result::Public::PreOrderItem",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "putaway_prep_inventories",
  "XTracker::Schema::Result::Public::PutawayPrepInventory",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "quarantine_processes",
  "XTracker::Schema::Result::Public::QuarantineProcess",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_consistencies",
  "XTracker::Schema::Result::Public::ReservationConsistency",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservations",
  "XTracker::Schema::Result::Public::Reservation",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_items",
  "XTracker::Schema::Result::Public::ReturnItem",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rma_request_details",
  "XTracker::Schema::Result::Public::RmaRequestDetail",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_quantities",
  "XTracker::Schema::Result::Public::RTVQuantity",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "size",
  "XTracker::Schema::Result::Public::Size",
  { id => "size_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "std_size",
  "XTracker::Schema::Result::Public::StdSize",
  { id => "std_size_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "stock_consistencies",
  "XTracker::Schema::Result::Public::StockConsistency",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_count_variants",
  "XTracker::Schema::Result::Public::StockCountVariant",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_order_items",
  "XTracker::Schema::Result::Public::StockOrderItem",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_recodes",
  "XTracker::Schema::Result::Public::StockRecode",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_transfers",
  "XTracker::Schema::Result::Public::StockTransfer",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "third_party_sku",
  "XTracker::Schema::Result::Public::ThirdPartySku",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "variant_measurements",
  "XTracker::Schema::Result::Public::VariantMeasurement",
  { "foreign.variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "variant_measurements_logs",
  "XTracker::Schema::Result::Public::VariantMeasurementsLog",
  { "foreign.variant_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SFU3543u7QsP9UM38nQisQ

use NAP::policy "tt", 'class';
use MooseX::NonMoose;
use MooseX::Params::Validate 'pos_validated_list';
# extends is a bit dodgy as we're doing a 'use base' in the autogenerated
# section, however we get big fat warning about inlining constructors without
# it... so let's keep it here and take it out if it breaks stuff
extends 'DBIx::Class::Core';
with 'XTracker::Role::WithPRLs',
     'XTracker::Role::CommonVariant';
with 'XTracker::Role::WithAMQMessageFactory';

use Log::Log4perl ':easy';

__PACKAGE__->has_many(
    'quantities' => 'XTracker::Schema::Result::Public::Quantity',
    { 'foreign.variant_id' => 'self.id' },
);

__PACKAGE__->has_many(
    "log_pws_stocks",
    "XTracker::Schema::Result::Public::LogPwsStock",
    { "foreign.variant_id" => "self.id" },
);

__PACKAGE__->has_many(
  "log_locations",
  "XTracker::Schema::Result::Public::LogLocation",
  { "foreign.variant_id" => "self.id" },
  {},
);

# This is a supporting outer-join relationship to allow prefetches and joins
# over 'might_have' relationships
__PACKAGE__->belongs_to(
    'outer_product' => 'XTracker::Schema::Result::Public::Product',
    { 'foreign.id' => 'self.product_id' },
    { join_type => "LEFT OUTER" },
);

use XTracker::Constants::FromDB qw(
                                    :flow_status
                                    :shipment_item_status
                                    :product_channel_transfer_status
                                    :pre_order_status
                                    :pre_order_item_status
                                    :stock_order_type
                                    :stock_order_item_status
                                );
use XTracker::Config::Local qw/config_section_slurp/;

use XTracker::Document::LargeSKULabel;
use XTracker::Document::SmallSKULabel;

=head2 prl_client

Returns the PRL token appropriate for the implied PRL concept of client, for
this variant. If you have the channel already, you can save a lookup by calling
the same-named method on that instead.

=cut

sub prl_client {
    my ( $self, $channel ) = shift;
    $channel //= $self->current_channel;
    return $channel->prl_client;
}

=head2 sku

This sub generates a sku for this variant.

=cut

sub sku {
    my ( $self ) = @_;
    my $pid = $self->product_id;
    my $sid = $self->size_id;
    LOGCONFESS( "Can't create sku - no product_id" ) unless defined $pid;
    LOGCONFESS( "Can't create sku - no size_id" ) unless defined $sid;
    return sprintf("%d-%03d", $pid, $sid );
}

# TODO: The following several subs should be moved into a component or somewhere
# where they can be shared with C<XTracker::Schema::Result::Voucher::Variant>

=head2 get_quantity_in_location

Look up the Quantity row to find how many items are in a particular location.

It's not a foreign key in the database, because the variant_id column in the
quantity table can refer to either a public.variant or a voucher.variant,
because of the way vouchers are
implemented.

=cut

sub get_quantity_in_location {
    my $self = shift @_;
    my ($location) = pos_validated_list(
        \@_,
        { isa => 'XTracker::Schema::Result::Public::Location' },
    );
    return $self->search_related('quantities', {
        'location_id' => $location->id,
    })->get_column('me.quantity')->sum || 0;
}

=head2 current_stock_on_channel

Returns the current stock for the variant on the given channel

=cut

sub current_stock_on_channel {
    my ( $self, $channel_id ) = @_;
    return $self->quantity_on_channel( $channel_id )
         + ( $self->picked_shipment_items_on_channel( $channel_id )->count || 0 )
         + ( $self->stock_transfers_on_channel( $channel_id )->count || 0 )
    ;
}

sub current_channel {
    my ($self) = @_;

    $self->product->get_product_channel->channel;
}

=head2 is_live_on_channel( $channel_id )

Determine if the variant is live on the given channel.

=cut

sub is_live_on_channel {
    my ( $self, $channel_id ) = @_;
    return $self->product->get_product_channel( $channel_id );
}

=head2 selected

Returns a resultset of selected shipment items for this variant.

=cut

sub selected {
    shift->shipment_items->selected;
}

=head2 selected_for_sample

Returns a resultset of selected shipment items that are part of transfer
(sample) shipment for this variant.

=cut

sub selected_for_sample {
    shift->selected->transfer_shipments;
}


=head2 get_measurements

Return a hash ref of measurement names and values for variant

=cut

sub get_measurements {

    my ($self) = @_;
    my $return_ref  = {};   # specify an empty HASH so exist checks to fail on it if it's empty

    my $var_meas_rs = $self->variant_measurements;
    while (my $var_meas =  $var_meas_rs->next ) {
        $return_ref->{ $var_meas->measurement->measurement } = $var_meas->value;
    }

    return $return_ref;

}

use JSON::XS ();
use List::MoreUtils 'uniq';
sub get_measurements_payload {
    my ($self,$channel_id) = @_;

    my $product = $self->product;
    $channel_id //= $product->get_product_channel->channel_id;

    my @variant_measurements = $self->search_related(
        'variant_measurements',{},
        { prefetch=>'measurement' }
    )->all;

    my %show = map {
        $_->measurement_id, $_,
    } $product->get_ordered_shown_measurements;

    my %values = map {
        $_->measurement_id, $_,
    } @variant_measurements;

    my %product_type_measurements = map {
        $_->measurement_id, $_,
    } $product->product_type
        ->search_related('product_type_measurements',
                         { channel_id => $channel_id })->all;

    my @all_keys = uniq(keys(%show),
                        keys(%values),
                        keys(%product_type_measurements));

    my @ret;
    for my $mid (@all_keys) {
        push @ret,{
            measurement_id => $mid,
            measurement_name => ($values{$mid}//$show{$mid}//$product_type_measurements{$mid})
                ->measurement->measurement,
            value => ( $values{$mid} ? $values{$mid}->value : '' ),
            visible => ($show{$mid} ? JSON::XS::true : JSON::XS::false),
        };
    }

    @ret = sort { $a->{measurement_name} cmp $b->{measurement_name} } @ret;

    return \@ret;
}

=head2 send_sku_update_to_prls

    $variant->send_sku_update_to_prls ({'amq'=>$amq});

If PRLs are turned on, sends a message to each PRL with the latest details.

=cut

sub send_sku_update_to_prls {
    my ($self, $args) = @_;

    my $amq = $args->{'amq'} ||
        $self->msg_factory;

    if ($self->prl_rollout_phase) {
        $amq->transform_and_send( 'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {'product_variant' => $self});
    }
}

=head2 get_on_order_quantity

=cut

sub get_ordered_quantity_for_channel {
    my ($self, $channel_id) = @_;

    my $quantity = 0;

    my @rows = $self->result_source->schema->resultset('Public::StockOrderItem')->search({
        variant_id => $self->id,
        cancel     => 0
    })->all;

    foreach my $row (@rows) {
        if ((( $row->stock_order->type_id == $STOCK_ORDER_TYPE__MAIN ) || ( $row->stock_order->type_id == $STOCK_ORDER_TYPE__REPLACEMENT )) && ( $row->stock_order->purchase_order->channel_id == $channel_id )) {
            $quantity += $row->quantity;
        }
    }

    return $quantity;
}

=head2 get_pre_ordered_count_in_channel

Returns count of pre_ordered variants for a specific channel.
=cut

sub get_pre_ordered_count_in_channel {
    my ($self, $channel_id) = @_;

    my $quantity = 0;

    $quantity = $self->result_source->schema->resultset('Public::PreOrderItem')->search({
        variant_id               => $self->id,
        pre_order_item_status_id => {'IN' => [
                                                $PRE_ORDER_ITEM_STATUS__CONFIRMED,
                                                $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                                $PRE_ORDER_ITEM_STATUS__EXPORTED
                                        ] },
    })->count;

    return $quantity;

}

=head2 get_stock_available_for_pre_order_for_channel

Returns count of total available stock at the point of call.

=cut

sub get_stock_available_for_pre_order_for_channel {
    my($self, $channel_id) = @_;

    my $quantity = $self->get_ordered_quantity_for_channel( $channel_id) - $self->get_pre_ordered_count_in_channel( $channel_id );

    return $quantity;

}

=head2 can_be_pre_ordered_in_channel

Returns true or false if this variant is available for pre order on the specific channel

=cut

sub can_be_pre_ordered_in_channel {
    my ($self, $channel_id) = @_;

    # check if the Product is still able to be Pre-Ordered
    return 0    unless ( $self->product->can_be_pre_ordered_in_channel( $channel_id ) );

    # work out the Stock based on what is on Order rather than Free Stock
    # as in a Pre-Order context it will be along time before there is any
    # actual Stock in the Warehouse.

    my $confirmed_variant_pre_orders_count = $self->get_pre_ordered_count_in_channel( $channel_id );

    # Are there any variants left 'on order' which can be sold?
    if ($confirmed_variant_pre_orders_count >= $self->get_ordered_quantity_for_channel($channel_id)) {
        return 0;
    }
    else {
        return 1;
    }
}

=head2 get_reservation_count_for_status

    my $count = $variant->get_reservation_count_for_status($RESERVATION_STATUS__PENDING);

Returns the row count from the reservations table where this variant has the supplied reservation status

=cut

sub get_reservation_count_for_status {
    my ($self, $status) = @_;

    return $self->search_related('reservations', {
        status_id => $status,
    }, {})->count();
}

=head2 get_estimated_shipping_window

Returns a hash ref of the form :

    {
        start_ship_date =  d-y-m,
        cancel_ship_date = d-y-m,
    }

For a given variant it find the latest (date) purchase order and
returns shipping window of the related stock order.

=cut

sub get_estimated_shipping_window {
    my $self       = shift;


    my $estimated_window = {};

    my $stock_order_item_rs =  $self->result_source->schema->resultset('Public::StockOrderItem')->search({
        'variant_id' => $self->id,
        'me.cancel'     => 0,
        'me.status_id'  => { 'IN' =>
            [
                $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED,
            ],
        },
    },{
        join => { stock_order => 'purchase_order' },
        order_by => 'date DESC, purchase_order.id DESC',
    });

    if ( $stock_order_item_rs->count ) {

        my $po_rec_id   = $stock_order_item_rs->first->stock_order->purchase_order->id;
        my $stock_order = $self->result_source->schema->resultset('Public::StockOrder')->search({
            'purchase_order_id' => $po_rec_id,
            'start_ship_date'   => { '!=' => undef },
            'cancel_ship_date'  => { '!=' => undef },
         } )->first ;

        if($stock_order) {
            $estimated_window->{start_ship_date}  = $stock_order->start_ship_date->dmy;
            $estimated_window->{cancel_ship_date} = $stock_order->cancel_ship_date->dmy;
        }

    }
    return $estimated_window;

}

=head2 update_standardised_size_mapping

Retrieve the standardised size id for a given variant, queries the StdSizeMapping table
using the designer size id and size scheme and looks for the related StdSize table.

=cut

sub update_standardised_size_mapping {
    my $self = shift;

    my $schema = $self->result_source()->schema();

    my $size_scheme = $self->product->product_attribute->size_scheme;

    return unless $size_scheme;

    my $std_size_mapping = $schema->resultset('Public::StdSizeMapping')->search(
        {
            'me.size_id' => $self->designer_size_id,
            'me.size_scheme_id' => $size_scheme->id
        },
    )->first;

    $self->update( { std_size_id => $std_size_mapping->std_size->id, } )
      if $std_size_mapping;

    return;
}

=head2 get_client

Return the client associated with this variant

=cut
sub get_client {
    my ($self) = @_;
    return $self->product()->get_client();
}

=head2 get_client

Return the third_party_sku value for this variant, if any

=cut
sub get_third_party_sku {
    my ($self) = @_;
    my $third_party_sku_obj = $self->third_party_sku();
    return ($third_party_sku_obj
        ? $third_party_sku_obj->third_party_sku()
        : undef
    );
}

=head2 large_label() : $large_sku_label_document

Return a L<XTracker::Document::LargeSKULabel> for this variant.

TEMPORARY
For DC2 and DC3 we need to add the current date. As this is the only
template difference between all DCs and GoodsIn/ReturnsQC, we will
add this as an attribute of the LargeSKULabel and make sure
that, in template, the current date is printed for DC2 and DC3 only
on ReturnsQC page

=cut

sub large_label {
    my $self = shift;
    my $date = shift;
    my $product = $self->product;

    return XTracker::Document::LargeSKULabel->new(
        colour   => $product->colour->colour,
        designer => $product->designer->designer,
        season   => $product->season->season,
        size     => $self->designer_size->size,
        sku      => $self->sku,
        # Temporary added until the standardisation
        # for all DCs kicks in
        (date    => $date)x!! $date,
    );
}

=head2 small_label() : $small_sku_label_document

Return a L<XTracker::Document::SmallSKULabel> for this variant.

=cut

sub small_label {
    my $self = shift;
    return XTracker::Document::SmallSKULabel->new(
        size => $self->designer_size->size,
        sku  => $self->sku,
    );
}

1;

use utf8;
package XTracker::Schema::Result::Voucher::Variant;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("voucher.variant");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "variant_id_seq",
  },
  "product_id",
  { data_type => "integer", is_nullable => 0 },
  "size_id_old",
  { data_type => "integer", default_value => 22, is_nullable => 0 },
  "nap_size_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "legacy_sku",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "type_id",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "size_id",
  { data_type => "integer", default_value => 999, is_nullable => 0 },
  "designer_size_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "std_size_id",
  { data_type => "integer", default_value => 4, is_nullable => 0 },
  "vtype",
  { data_type => "text", default_value => "voucher", is_nullable => 0 },
  "voucher_product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("variant_voucher_product_id_key", ["voucher_product_id"]);
__PACKAGE__->has_many(
  "log_rtv_stocks",
  "XTracker::Schema::Result::Public::LogRtvStock",
  { "foreign.voucher_variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orphan_items",
  "XTracker::Schema::Result::Public::OrphanItem",
  { "foreign.voucher_variant_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Voucher::Product",
  { id => "voucher_product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "putaway_prep_inventories",
  "XTracker::Schema::Result::Public::PutawayPrepInventory",
  { "foreign.voucher_variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.voucher_variant_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_order_items",
  "XTracker::Schema::Result::Public::StockOrderItem",
  { "foreign.voucher_variant_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mKSuGIn1p/sWTfQ913hN/g

__PACKAGE__->has_many(
    quantities => 'XTracker::Schema::Result::Public::Quantity',
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
__PACKAGE__->many_to_many( 'locations', quantities => 'location' );

use Moose;
use MooseX::NonMoose;
extends 'DBIx::Class::Core';
with 'XTracker::Role::WithPRLs',
     'XTracker::Role::CommonVariant';

use XTracker::Role::WithAMQMessageFactory;

use XTracker::Config::Local qw/config_section_slurp/;
use XTracker::Constants::FromDB qw( :flow_status :shipment_item_status );

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

Generate a sku for this voucher.

=cut

sub sku {
    my $self = shift;
    return join q{-}, $self->voucher_product_id, $self->size_id;
}

=head2 size() : $size_row

Returns a DBIC C<Public::Size> row with an id of '999' and a size of 'N/A -
Voucher' (personally I would have preferred 'One size'). Note that this object
does B<not> exist in the database.

=head2 designer_size() : $size_row

An alias for L<size>.

=cut

sub size {
    my $self = shift;
    return $self->result_source
                ->schema
                ->resultset('Public::Size')
                ->new({id => $self->size_id, size => 'N/A - Voucher'});
}
*designer_size = \&size;

=head2 current_stock_on_channel

Returns the current stock for the variant on the given channel. Replaces a
DBIC call made in C<XTracker::Database::Logging::log_stock>.

=cut

sub current_stock_on_channel {
    my ( $self, $channel_id ) = @_;
    # FIXME: Currently the shipments have not been set up yet for vouchers, so
    # commenting out until then...
    # FIXME: Also check the numbers add up...!
    return $self->quantity_on_channel( $channel_id )
        #+ $self->picked_shipment_items_on_channel( $channel_id )->count
        #+ $self->stock_transfers_on_channel( $channel_id )->count
    ;
}

=head2 returns the channel object on which the product is being sold.

=cut

sub current_channel {
    my ($self) = @_;

    $self->product->get_product_channel->channel;
}

=head2 selected

Returns a resultset of selected shipment items for this variant.

=cut

sub selected {
    shift->shipment_items->selected;
}

=head2 selected_for_sample

Returns a resultset of selected shipment items that are part of a shipment for
this variant.

=head3 NOTE

This is actually just here for compatibility with the identically named method
in L<XTracker::Schema::Result::Public::Variant> - we never do voucher samples
so it will always return an empty resultset.

=cut

sub selected_for_sample {
    shift->shipment_items->selected->transfer_shipments;
}

=head2 descriptive_value

Returns a string of the value + currency for display to warehouse operatives

=cut

sub descriptive_value {
    my $self = shift;

    my $currency_name = $self->product->currency->currency;
    my $value = $self->product->value;

    return sprintf("%s %.2f", $currency_name, $value );
}


=head2 send_sku_update_to_prls

    $voucher_variant->send_sku_update_to_prls ({'amq'=>$amq});

If PRLs are turned on, sends a message for the voucher variant to each PRL with
the latest details.

=cut

sub send_sku_update_to_prls {

    my ($self, $args) = @_;

    my $amq = $args->{'amq'} ||
        XTracker::Role::WithAMQMessageFactory->build_msg_factory;

    if ($self->prl_rollout_phase) {
        $amq->transform_and_send( 'XT::DC::Messaging::Producer::PRL::SKUUpdate' => {'voucher_variant' => $self});
    }
}

=head2 notify_product_service

    $voucher->notify_product_service();

Sends a message to the product service about this voucher.

=cut

sub notify_product_service {
    my ( $self ) = @_;

    my $amq = XTracker::Role::WithAMQMessageFactory->build_msg_factory;

    $amq->transform_and_send('XT::DC::Messaging::Producer::Product::Notify', {
        voucher_id => $self->voucher_product_id,
        channel_id => $self->product->channel_id,
    });
}

=head2 get_client

Return the client associated with this voucher

=cut
sub get_client {
    my ($self) = @_;
    return $self->product()->get_client();
}

1;

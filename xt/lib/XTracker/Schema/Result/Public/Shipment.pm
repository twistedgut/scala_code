use utf8;
package XTracker::Schema::Result::Public::Shipment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_id_seq",
  },
  "date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "shipment_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_address_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "gift",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "gift_message",
  { data_type => "text", is_nullable => 1 },
  "outward_airway_bill",
  {
    data_type => "varchar",
    default_value => "none",
    is_nullable => 1,
    size => 40,
  },
  "return_airway_bill",
  {
    data_type => "varchar",
    default_value => "none",
    is_nullable => 1,
    size => 40,
  },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "telephone",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "mobile_telephone",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "packing_instruction",
  { data_type => "text", is_nullable => 0 },
  "shipping_charge",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "comment",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "delivered",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "gift_credit",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "store_credit",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "legacy_shipment_nr",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "destination_code",
  { data_type => "varchar", is_nullable => 1, size => 3 },
  "shipping_charge_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "shipping_account_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "premier_routing_id",
  {
    data_type      => "smallint",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "real_time_carrier_booking",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "av_quality_rating",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "sla_priority",
  { data_type => "integer", is_nullable => 1 },
  "sla_cutoff",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "has_packing_started",
  { data_type => "boolean", is_nullable => 1 },
  "packing_other_info",
  { data_type => "text", is_nullable => 1 },
  "signature_required",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "nominated_delivery_date",
  { data_type => "date", is_nullable => 1 },
  "nominated_dispatch_time",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "nominated_earliest_selection_time",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "is_picking_commenced",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_prioritised",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "wms_initial_pick_priority",
  { data_type => "integer", is_nullable => 1 },
  "wms_deadline",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "wms_bump_pick_priority",
  { data_type => "integer", is_nullable => 1 },
  "wms_bump_deadline",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "has_valid_address",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "force_manual_booking",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "allocations",
  "XTracker::Schema::Result::Public::Allocation",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "credit_logs",
  "XTracker::Schema::Result::Voucher::CreditLog",
  { "foreign.spent_on_shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_delivery__shipments",
  "XTracker::Schema::Result::Public::LinkDeliveryShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_manifest__shipments",
  "XTracker::Schema::Result::Public::LinkManifestShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_orders__shipments",
  "XTracker::Schema::Result::Public::LinkOrderShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_return_arrival__shipments",
  "XTracker::Schema::Result::Public::LinkReturnArrivalShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_routing_export__shipments",
  "XTracker::Schema::Result::Public::LinkRoutingExportShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_routing_schedule__shipments",
  "XTracker::Schema::Result::Public::LinkRoutingScheduleShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "link_shipment__promotion",
  "XTracker::Schema::Result::Public::LinkShipmentPromotion",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_sms_correspondence__shipments",
  "XTracker::Schema::Result::Public::LinkSmsCorrespondenceShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_stock_transfer__shipments",
  "XTracker::Schema::Result::Public::LinkStockTransferShipment",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_shipment_rtcb_states",
  "XTracker::Schema::Result::Public::LogShipmentRtcbState",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_shipment_signature_requireds",
  "XTracker::Schema::Result::Public::LogShipmentSignatureRequired",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "premier_routing",
  "XTracker::Schema::Result::Public::PremierRouting",
  { id => "premier_routing_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "renumerations",
  "XTracker::Schema::Result::Public::Renumeration",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "returns",
  "XTracker::Schema::Result::Public::Return",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment_address",
  "XTracker::Schema::Result::Public::OrderAddress",
  { id => "shipment_address_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "shipment_address_logs",
  "XTracker::Schema::Result::Public::ShipmentAddressLog",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_boxes",
  "XTracker::Schema::Result::Public::ShipmentBox",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment_class",
  "XTracker::Schema::Result::Public::ShipmentClass",
  { id => "shipment_class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "shipment_email_logs",
  "XTracker::Schema::Result::Public::ShipmentEmailLog",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_extra_items",
  "XTracker::Schema::Result::Public::ShipmentExtraItem",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_flags",
  "XTracker::Schema::Result::Public::ShipmentFlag",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_hold_logs",
  "XTracker::Schema::Result::Public::ShipmentHoldLog",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_holds",
  "XTracker::Schema::Result::Public::ShipmentHold",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_internal_email_logs",
  "XTracker::Schema::Result::Public::ShipmentInternalEmailLog",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_items",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_message_logs",
  "XTracker::Schema::Result::Public::ShipmentMessageLog",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_notes",
  "XTracker::Schema::Result::Public::ShipmentNote",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_print_logs",
  "XTracker::Schema::Result::Public::ShipmentPrintLog",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment_status",
  "XTracker::Schema::Result::Public::ShipmentStatus",
  { id => "shipment_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "shipment_status_logs",
  "XTracker::Schema::Result::Public::ShipmentStatusLog",
  { "foreign.shipment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipment_type",
  "XTracker::Schema::Result::Public::ShipmentType",
  { id => "shipment_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_account",
  "XTracker::Schema::Result::Public::ShippingAccount",
  { id => "shipping_account_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_charge_table",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { id => "shipping_charge_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many("deliveries", "link_delivery__shipments", "delivery");
__PACKAGE__->many_to_many("orders", "link_orders__shipments", "orders");
__PACKAGE__->many_to_many(
  "return_arrivals",
  "link_return_arrival__shipments",
  "return_arrival",
);
__PACKAGE__->many_to_many(
  "routing_exports",
  "link_routing_export__shipments",
  "routing_export",
);
__PACKAGE__->many_to_many(
  "stock_transfers",
  "link_stock_transfer__shipments",
  "stock_transfer",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ojWDQkmymjmwxqkoNstWAw

# set-up a inner join to the Shipment Items table which
# should be more efficient when you want Shipments that
# only have Shipment Items
__PACKAGE__->has_many(
  "shipment_items_ij",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { "foreign.shipment_id" => "self.id" },
  { join_type => 'INNER' },
);

=head1 NAME

XTracker::Schema::Result::Public::Shipment

=head1 METHODS

=cut

use MooseX::Params::Validate 'pos_validated_list', 'validated_list', 'validated_hash';
use boolean; # true/false
use Carp;
use XTracker::Logfile qw( xt_logger );
use XTracker::SchemaHelper qw(:records);
use XTracker::Barcode;
use XTracker::Config::Local qw(
    comp_addr
    comp_contact_hours
    comp_fax
    comp_freephone
    comp_tel
    config_section
    config_section_slurp
    config_var
    customercare_email
    dc_address
    get_packing_station_printers
    get_ups_qrt
    return_addr
    return_export_reason_prefix
    return_postcode
    returns_email
);
use XTracker::Database::OrderPayment    qw( process_payment );
use XTracker::Database::Invoice         qw( create_invoice create_invoice_item log_invoice_status );
use XTracker::Database::Currency        qw( get_currency_glyph_map );
use XTracker::PrintFunctions qw(
    print_mrp_sticker
    get_printer_by_name
    create_document
    print_document
    log_shipment_document
    path_for_print_document
    document_details_from_name
);
use XTracker::AllocateManager;
use XTracker::Constants         qw( :application );
use XTracker::Constants::FromDB qw(
    :allocation_status
    :carrier
    :container_status
    :country
    :customer_issue_type
    :distrib_centre
    :flag
    :flow_status
    :note_type
    :order_status
    :prl
    :pws_action
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :shipment_class
    :shipment_hold_reason
    :shipment_item_on_sale_flag
    :shipment_item_returnable_state
    :shipment_item_status
    :shipment_status
    :shipment_type
    :shipping_charge_class
    :ship_restriction
    :sub_region
);
use vars qw/$PRL__DEMATIC $PRL__FULL/;
use XTracker::Utilities qw( number_in_list prefix_country_code_to_phone known_mobile_number_for_country );
use XTracker::Database::Shipment qw( set_shipment_on_hold get_postcode_shipping_charges check_shipment_restrictions );

use Moose;
with    'XTracker::Schema::Role::WithStateSignature',
        'XTracker::Schema::Role::RoutingSchedule',
        'XTracker::Schema::Role::CanUseCSM',
        'XTracker::Schema::Role::GetTelephoneNumber',
        'XTracker::Schema::Role::Hierarchy',
        'XTracker::Role::WithAMQMessageFactory',
        'XTracker::Role::AccessConfig',
        'XTracker::Role::WithXTLogger',
        'XTracker::Role::SOS::Shippable';

use DateTime;
use Math::Round;
use List::MoreUtils qw ( uniq any none );
use LWP::Simple qw($ua getstore is_error);
use File::Basename;
use MooseX::Params::Validate;

use XTracker::Printers::Zebra::PNG;

use XTracker::Database::Customer qw( get_order_address_customer_name );

use XTracker::Document::DangerousGoodsNote;
use XTracker::Document::ReturnProforma;

use XT::Net::WebsiteAPI::Client::NominatedDay;
use XT::Data::NominatedDay::Order;
use XTracker::Order::Printing::GiftMessage;

use XT::Data::Packing::Summary;
use Try::Tiny;
use XT::Warehouse;
use NAP::XT::Exception::Shipment::OrderRequired;

use XTracker::Constants ':application';
use NAP::Carrier;
use XTracker::Shipment::Classify;

use XTracker::DBEncode qw(decode_db encode_db);
use XTracker::EmailFunctions qw/send_email send_internal_email/;

use XT::Domain::Payment::Basket;

use Readonly;
Readonly my $SOS_ALERT_EMAIL_TEMPLATE => 'email/internal/sos_sla_call_failed.tt';

__PACKAGE__->load_components('FilterColumn');
foreach (qw[ gift_message email comment ]) {
    __PACKAGE__->filter_column($_ => {
        filter_from_storage => sub { decode_db($_[1]) },
        filter_to_storage => sub { encode_db($_[1]) },
    });
}

__PACKAGE__->load_components('+XTracker::Utilities::DBIC::LocalDate');

# This is the correct relation replacing the SchemaLoader generated
# link_orders__shipments - correctly returning a row instead of an rs
# except there's no unique constraint on link_orders__shipment.shipment_id, so
# there could be multiple rows, giving us an arbitrary one of them
__PACKAGE__->might_have(
    'link_orders__shipment' => 'XTracker::Schema::Result::Public::LinkOrderShipment',
    { 'foreign.shipment_id' => 'self.id' },
);
# And this is the same relationship as the previous one, pick one,  and delete
# the other after making sure it's never called when we have time!
__PACKAGE__->might_have(
    'link_order__shipment' => 'XTracker::Schema::Result::Public::LinkOrderShipment',
    { 'foreign.shipment_id' => 'self.id' },
);
# this is an INNER JOIN version of the 'link_orders__shipment' which can be used
# when searching for Shipments that you know are for Orders which should be more
# efficient from a database point of view.
__PACKAGE__->might_have(
    'link_orders__shipment_ij' => 'XTracker::Schema::Result::Public::LinkOrderShipment',
    { 'foreign.shipment_id' => 'self.id' },
    { join_type => 'INNER' },
);

# This accessor should be removed and we should use
# link_stock_transfer__shipments
__PACKAGE__->might_have(
    'link_stock_transfer__shipment' => 'XTracker::Schema::Result::Public::LinkStockTransferShipment',
    { 'foreign.shipment_id' => 'self.id' },
);

# This relation is incorrect - a shipment can have two returns if one has been
# cancelled - DJ
__PACKAGE__->might_have(
    'return' => 'XTracker::Schema::Result::Public::Return',
    { 'foreign.shipment_id' => 'self.id' },
);

__PACKAGE__->many_to_many(
    manifests => 'link_manifest__shipments' => 'manifest'
);

__PACKAGE__->many_to_many(
    routing_schedules => 'link_routing_schedule__shipments' => 'routing_schedule'
);

# This gives us the return that this exchange shipment belongs to. I *think*
# this has to be a might_have as opposed to a has_many (one exchange shipment
# can't have multiple returns, can it?)
__PACKAGE__->might_have(
    exchange_return => 'XTracker::Schema::Result::Public::Return',
    { 'foreign.exchange_shipment_id' => 'self.id' },
);

sub get_system_time_zone {
    my ($self) = @_;
    return $self->get_config_var('DistributionCentre', 'timezone');
}

=head2 allocate

If we are using the PRL architecture, updates the allocation for a given
shipment. Can safetly be invoked outside the PRL architecture. Requires an AMQ
message factory as its only argument. Idempotent, assuming the shipment hasn't
changed since the last time you called it.

If you don't pass in a factory, we'll create one.

=cut

sub allocate {
    my ( $self, $factory, $operator_id ) = validated_list(
        \@_,
        factory     => { optional => true },
        operator_id => { isa => 'Int' },
    );

    return unless XT::Warehouse->instance->has_prls;

    # We instantiate a msg factory here, rather than inside AllocateManager, as
    # we definitely have a schema here.
    $factory //= $self->msg_factory;
    return XTracker::AllocateManager->allocate_shipment({
        shipment    => $self,
        factory     => $factory,
        operator_id => $operator_id
    });
}

=head2 find_or_create_allocation_to_add_item_for_prl

Finds or creates an active allocation for this shipment, in the PRL which is
given as the only argument. If the only existing active allocations already
contain the maximum number of items allowed per allocation for that PRL, it
creates a new one.

=cut

sub find_or_create_allocation_to_add_item_for_prl {
    my ( $self, $prl ) = @_;
    die "expected prl" unless $prl;

    my $prl_row = XT::Domain::PRLs::get_prl_from_name({
        prl_name => $prl,
    }) || confess "Invalid PRL '$prl' - no prl matching that name in db";

    # Find active allocations. There could be more than one, if it's a large shipment.
    my @allocations = $self->search_related( allocations => {
        prl_id => $prl_row->id,
        status_id => { IN => [
            $ALLOCATION_STATUS__REQUESTED,
            $ALLOCATION_STATUS__ALLOCATED,
        ] },
    });

    # There is a maximum number of items per allocation - we can't add
    # to an allocation that has already got that many.
    @allocations = grep {$_->allocation_items->count < $prl_row->max_allocation_items} @allocations;

    # If no valid allocation was found, create one.
    unless ( @allocations ) {
        push( @allocations, $self->create_related( allocations => {
            prl_id => $prl_row->id,
            status_id => $ALLOCATION_STATUS__REQUESTED,
        }));
    }

    return $allocations[0];
}

=head2 is_standard_class

Checks if the class of this shipment is B<Standard>

=cut

sub is_standard_class {
    $_[0]->shipment_class_id == $SHIPMENT_CLASS__STANDARD;
}

=head2 is_press_class

Checks if the class of this shipment is B<Press>

=cut

sub is_press_class {
    $_[0]->shipment_class_id == $SHIPMENT_CLASS__PRESS;
}

=head2 is_sample_shipment

We have confusingly named shipment classes that are all used for samples - this
method will return true if this shipment's class is one of these.

=cut

sub is_sample_shipment {
    return XTracker::Shipment::Classify->new->is_sample(shift->shipment_class_id);
}

=head2 is_sample_class

Checks if the class of this shipment is B<Sample>

=head3 NOTE

Nothing ever seems to be C<$SHIPMENT_CLASS__SAMPLE> Samples are in fact
implemented as C<$SHIPMENT_CLASS__TRANSFER_SHIPMENTs>

TODO: confirm and delete this method, db patch to remove B<Sample> class (if
FKs allow) or, if it is used, adjust this comment to explain when it's used.

=cut

sub is_sample_class {
    $_[0]->shipment_class_id == $SHIPMENT_CLASS__SAMPLE;
}

=head2 is_replacement_class

Checks if the class of this shipment is B<Press>

=cut

sub is_replacement_class {
    $_[0]->shipment_class_id == $SHIPMENT_CLASS__REPLACEMENT;
}

=head2 is_transfer_shipment

Returns a true value if the class of this shipment is B<Transfer Shipment>

=cut

sub is_transfer_shipment {
    $_[0]->shipment_class_id == $SHIPMENT_CLASS__TRANSFER_SHIPMENT;
}

=head2 is_rtv_shipment

Returns a true value if the class of this shipment is B<RTV Shipment>

=cut

sub is_rtv_shipment {
    return $_[0]->shipment_class_id == $SHIPMENT_CLASS__RTV_SHIPMENT;
}

=head2 is_exchange

Checks if the class of this shipment is B<Exchange>

=cut

=head2 is_exchange_shipment

An alias for C<< $self->is_exchange >>

=cut

sub is_exchange {
    $_[0]->shipment_class_id == $SHIPMENT_CLASS__EXCHANGE;
}
*is_exchange_class = \&is_exchange;

=head2 is_reshipment

Checks if the class of this shipment is B<Re-Shipment>

=cut

sub is_reshipment {
    $_[0]->shipment_class_id == $SHIPMENT_CLASS__RE_DASH_SHIPMENT;
}

=head2 is_premier

Checks if the type of this shipment is B<Premier>.

=cut

sub is_premier {
    $_[0]->shipment_type_id == $SHIPMENT_TYPE__PREMIER;
}

=head2 is_domestic

Checks if the type of this shipment is B<Domestic>.

=cut

sub is_domestic {
    $_[0]->shipment_type_id == $SHIPMENT_TYPE__DOMESTIC;
}

=head2 is_unknown

Checks if the type of this shipment is B<Unknown>.

=cut

sub is_unknown { shift->shipment_type_id == $SHIPMENT_TYPE__UNKNOWN; }

=head2 is_international

Checks if the type of this shipment is B<International>.

=cut

sub is_international { shift->shipment_type_id == $SHIPMENT_TYPE__INTERNATIONAL; }

=head2 is_international_ddu

Checks if the type of this shipment is B<International DDU>.

=cut

sub is_international_ddu { shift->shipment_type_id == $SHIPMENT_TYPE__INTERNATIONAL_DDU; }

=head2 unselected_items

Returns items with a status of B<New>.

=cut

sub unselected_items {
    return shift->shipment_items->search({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW });
}

=head2 selected_items

Returns items with a status of B<Selected>.

=cut

sub selected_items {
    return shift->shipment_items->search({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED });
}

=head2 picked_items

Returns items with a status of B<Picked>.

=cut

sub picked_items {
    return shift->shipment_items->search({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED });
}

=head2 unpicked_items

Returns items with a status of B<New> or B<Selected>.

=cut

sub unpicked_items {
    return shift->shipment_items->search({
         shipment_item_status_id => {
                -in => [ $SHIPMENT_ITEM_STATUS__NEW,
                         $SHIPMENT_ITEM_STATUS__SELECTED ]
         }
    });
}

=head2 non_cancelled_items

Returns items with a status not of B<Cancel Pending> or B<Cancelled>.

=cut

=head2 non_canceled_items

An alias for C<$self->non_cancelled_items>

=cut

sub non_cancelled_items {
    return shift->shipment_items->search({
         shipment_item_status_id => {
                -not_in => [ $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                             $SHIPMENT_ITEM_STATUS__CANCELLED ]
         }
    });
}
sub non_canceled_items { shift->non_cancelled_items }

=head2 active_items

Returns items with a status of:

=over

=item New

=item Selected

=item Picked

=item Packing Exception

=item Packed

=item Dispatched

=back

=cut

sub active_items {
    return shift->shipment_items->search({
         shipment_item_status_id => {
                -in => [
                    $SHIPMENT_ITEM_STATUS__NEW,
                    $SHIPMENT_ITEM_STATUS__SELECTED,
                    $SHIPMENT_ITEM_STATUS__PICKED,
                    $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                    $SHIPMENT_ITEM_STATUS__PACKED,
                    $SHIPMENT_ITEM_STATUS__DISPATCHED,
                ]
         }
    });
}

=head2 cancelled_items

Returns items with a status of B<Cancel Pending> or B<Cancelled>.

=cut

sub canceled_items {
    return shift->shipment_items->search({
         shipment_item_status_id => {
                -in => [ $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                         $SHIPMENT_ITEM_STATUS__CANCELLED ]
         }
    });
}

=head2 is_multi_item

Checks if the shipment has more than one non-cancelled shipment item.

=cut

sub is_multi_item { return shift->non_cancelled_items->count > 1; }

=head2 get_picked_items_by_container

Returns an arrayref of shipment items with a status of B<Picked> or B<Packing
Exception> and are in a container.

=cut

sub get_picked_items_by_container {
    my $self = shift;
    my $items = $self->shipment_items->search({
                    shipment_item_status_id => { -in => [
                        $SHIPMENT_ITEM_STATUS__PICKED,
                        $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                    ] },
                },
                {order_by => 'id'});
    my $return = {};
    while (my $item = $items->next){
        next if $item->is_virtual_voucher; # these clearly won't be picked
        next unless defined $item->container;
        push @{$return->{$item->container->id}}, $item;
    }
    $return;
}

=head2 is_awaiting_return

Checks if a shipment has a status of B<Exchange Hold> or B<Return Hold>.

=cut

sub is_awaiting_return {
    my ($self) = @_;

    # Shipment Statuses:
    # - RETURN_HOLD means we are waiting for the goods to be returned
    # - EXCHANGE_HOLD means we are *also* waiting for some extra debit to happen (duties etc.)

    return $self->is_on_exchange_hold || $self->is_on_return_hold;
}

=head2 is_active

Checks if a shipment is not B<Dispatched> or B<Cancelled>.

=cut

sub is_active {
    my ($self) = @_;

    return !$self->is_dispatched && !$self->is_cancelled;
}

=head2 is_on_return_hold

Checks if a shipment has a status of B<Return Hold>. An exchange is in this
status when we are waiting for the goods to be returned.

=cut

sub is_on_return_hold {
    shift->shipment_status_id == $SHIPMENT_STATUS__RETURN_HOLD;
}

=head2 is_cancelled

Checks if a shipment has a status of B<Return Hold>.

=cut

sub is_cancelled { shift->shipment_status_id == $SHIPMENT_STATUS__CANCELLED; }

=head2 is_dispatched

Checks if a shipment has a status of B<Dispatched>.

=cut

sub is_dispatched { shift->shipment_status_id == $SHIPMENT_STATUS__DISPATCHED; }

=head2 is_on_exchange_hold

Checks if a shipment has a status of B<Exchange Hold>. An exchange is in this
status when we are waiting for the goods to be returned I<and> some extra
debit to happen (duties etc.).

=cut

sub is_on_exchange_hold {
    shift->shipment_status_id == $SHIPMENT_STATUS__EXCHANGE_HOLD;
}

=head2 is_lost

Returns a true value if the shipment has a status of B<Lost>.

=cut

sub is_lost { shift->shipment_status_id == $SHIPMENT_STATUS__LOST; }

=head2 packing_exception_items

Return items that have a status of B<Packing Exception>.

=cut

sub packing_exception_items {
    my ($self) = @_;
    return $self->search_related('shipment_items',{
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
    });
}

=head2 qc_failed_items

An alias for C<< $self->packing_exception_items >>.

=cut

sub qc_failed_items { return shift->packing_exception_items; }

=head2 missing_items

Returns items with a status of B<Packing Exception> without an associated
container.

=cut

sub missing_items {
    return shift->packing_exception_items->search({ container_id => undef });
}

=head2 is_at_packing_exception

Figures out of the shipment has been QC failed for any reason.

=cut

sub is_at_packing_exception {
    my ($self) = @_;
    return 1 if $self->has_packing_exception_items;
    return 1 if $self->containers->count({
        status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS
    });
    return 1 if
        grep { $_->qc_failure_reason }
        $self->search_related('shipment_items', {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
            container_id => undef,
        })->all;
    return 1 if $self->shipment_extra_items->count;
}

=head2 has_packing_exception_items

Checks if the shipment has any items with a status of B<Packing Exception>.

=cut

sub has_packing_exception_items {
    my ($self) = @_;
    return $self->packing_exception_items->count;
}

=head2 is_packing_exception_completed

Checks if packing exception has been completed.

=cut

# contains no items that have problems
sub is_packing_exception_completed {
    my ($self) = @_;

    return '' if $self->has_packing_exception_items;

    return '' if $self->shipment_extra_items->count;

    return '' if
      $self->search_related('shipment_items', {
                                     shipment_item_status_id => {
                                         -not_in => [ $SHIPMENT_ITEM_STATUS__SELECTED,
                                                      $SHIPMENT_ITEM_STATUS__PICKED,
                                                      $SHIPMENT_ITEM_STATUS__NEW ]
                                     },
                                     container_id => { '!=' => undef },
                                 })->count;
    return 1;
}


=head2 get_charge_class_id

Returns shipping charge class id for current shipment

=cut

sub get_charge_class_id {
    my $self = shift;
    my $shipping_charge_class = $self->get_shipping_charge_class();
    return ($shipping_charge_class ? $shipping_charge_class->id : '');
}


=head2 charge_class

Will return 'Same Day', 'Air', 'Ground' or ''

=cut

sub charge_class {
    my $self = shift;
    my $shipping_charge_class = $self->get_shipping_charge_class();
    return ($shipping_charge_class ? $shipping_charge_class->class : '');
}

=head2 is_carrier_automated() : Bool

Returns a boolean telling you whether this shipment is automated (this method
is an alias for real_time_carrier_booking).

=cut

sub is_carrier_automated {
    return shift->real_time_carrier_booking;
}

=head2 in_premier_area

Determine if the shipment is in a premier area. A port of
C<XTracker::Database::Shipment::is_premier>

=cut

sub in_premier_area {

    my $shipment = shift;
    my $schema = $shipment->result_source->schema;

    eval {

        my $order_address = $shipment->shipment_address;

        my %charges = get_postcode_shipping_charges(
            $schema->storage->dbh,
            {
                country => $order_address->country,
                postcode => $order_address->postcode,
                channel_id => $shipment->order->channel_id,
            }
        );

        foreach my $charge (keys %charges) {
            if ( $charges{$charge}->{class_id} == $SHIPPING_CHARGE_CLASS__SAME_DAY ) {
                return 1;
            }
        }
    };

    if ( $@ ) {
        # Invalid postcodes and such can cause an error. In this instance,
        # we probably don't want it to be fatal
        carp $@;
    }

    return;
}

=head2 update_status( $status_id, $operator_id )

Update and log the status of this shipment.

=cut

# TODO if you make changes here, remember to update
# XTracker::Database::Shipment::update_shipment_status too
# TODO really, they should both be merged but there's a weird return value...
sub update_status {
    my ( $self, $status_id, $operator_id ) = @_;

    # Any hold (check for virtual voucher autopick/dispatch)
    my $was_on_any_hold = $self->is_on_hold;

    # Regrettably we need to keep calling discard_changes as some of the
    # updates are done at DBI-level :/
    $self->result_source->schema->txn_do(sub {
        $self->change_status_to($status_id, $operator_id);

        # We can return unless the shipment was released from any hold
        return unless $self->is_processing;
        return unless $was_on_any_hold;

        # The shipment's been released, clear the below hold records and
        # validate the address again
        $self->clear_shipment_hold_records_for_reasons(
            $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
            $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
        );
        # Note that if the address fails due to non-Latin-1 characters this
        # will put the shipment on hold
        $self->validate_address({ operator_id => $operator_id });

        # If we're still processing, check the address and hold if it's invalid
        $self->hold_if_invalid({ operator_id => $operator_id })
            if $self->discard_changes->is_processing;

        # If we're still processing check if we need to hold for third party
        # payment reasons
        $self->update_status_based_on_third_party_psp_payment_status($operator_id)
            if $self->discard_changes->is_processing;

        # If we're not processing any more, we're done
        return unless $self->discard_changes->is_processing;

        # We shouldn't have a hold reason if we're not on hold any more, so
        # delete any if we still have some
        $self->shipment_holds->delete;

        $self->apply_SLAs();
        if ( $self->is_standard_class ){
            $self->auto_pick_virtual_vouchers( $operator_id );
            $self->dispatch_virtual_voucher_only_shipment( $operator_id );
        }

        # Shipments coming off hold should be reallocated
        $self->allocate({ operator_id => $operator_id });

        # Shipment is now processing, so send update to Mercury - we have the
        # usual message sending/transaction race condition here - don't know
        # which way round cause us less pain, so keeping it in the transaction
        # is just an arbitrary decision
        $self->send_release_update();
    });

    # Shipment is on hold so send an update to Mercury
    $self->send_hold_update() if $self->is_on_hold;

    return $self;
}

sub send_hold_update {
    my $self = shift;
    return unless $self->is_on_hold;
    my $hold = $self->shipment_holds->first;
    my $reason = defined $hold ? $hold->shipment_hold_reason->reason : 'No reason';
    my $comment = defined $hold ? $hold->comment : 'No comment';
    if($self->can_send_shipment_status_updates()) {
        $self->send_status_update({
            hold_reason     => $reason,
            comment         => $comment
        });
    }
}

sub send_release_update {
    my $self = shift;
    return if $self->is_on_hold;
    if($self->can_send_shipment_status_updates()) {
        $self->send_status_update({
            hold_reason     => 'Released',
            comment         => 'Released from hold'
        });
    }
}

sub send_status_update {
    my ($self, $params) = @_;

    my $defaults = {
        shipment_id     => $self->id,
        order_number    => $self->order->order_nr,
        shipment_status => $self->shipment_status->status,
        brand           => $self->order->channel->web_brand_name,
        region          => $self->order->channel->distrib_centre->alias
    };

    $self->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::Shipping::HoldStatusUpdate',
        {%$defaults, %$params}
    );
}

sub can_send_shipment_status_updates {
    my $self = shift;
    return 0 if (!$self->order);
    return $self->order->channel->get_can_send_shipment_updates();
}

=head2 cancel(:operator_id!, :customer_issue_type_id!, :notes = 'Cancel item $shipment_item_id', :stock_manager = $stock_manager) : $shipment | Undef

Cancels the shipment and all its items. Will automatically generate a stock
manager if not provided one. Returns the shipment object if successful or undef
if it's a no-op.

Make sure you wrap this call around code that determines whether or not to send
IWS a shipment_cancel message. It would be nice for it to live here - however
we can't as we'd be vulnerable to a race condition when the call is wrapped in
a transaction in the caller, where IWS sends a message I<back> to us before the
transaction has completed (believe it or not!), which sees the shipment in the
wrong status and fails to consume.

Use the following code to do this:

  # The race condition only occurs when you have a transaction in the caller
  $schema->txn_do(sub{

    # Check if we need to send a message to IWS *before* cancellation
    my $warehouse = XT::Warehouse->instance;
    my $iws_knows = ($warehouse->has_iws || $warehouse->has_ravni)
                 && $shipment->does_iws_know_about_me;

    $shipment->$do_stuff;
    $shipment->cancel(%args);
  });

  # Send a message after the transaction has committed to IWS if it's there and
  # it knows about this shipment
  $self->msg_factory->transform_and_send(
      'XT::DC::Messaging::Producer::WMS::ShipmentCancel',
      { shipment_id => $self->id }
  ) if $iws_knows;

=cut

# NOTE: READ THE POD FOR BEFORE CALLING THIS!
sub cancel {
    my $self = shift;
    my ( $operator_id, $customer_issue_type_id, $notes, $do_pws_update,
            $only_allow_selected_items, $stock_manager )
        = validated_list(\@_,
        operator_id            => { isa => 'Int', },
        customer_issue_type_id => { isa => 'Int', },
        notes                  => { isa => 'Str', optional => 1 },
        do_pws_update          => { isa => 'Bool', default => 1 },
        only_allow_selected_items => { isa => 'Bool', default => 0 },
        stock_manager          => {
            does => 'XTracker::WebContent::Roles::StockManager',
            default => $self->get_channel->stock_manager,
        },
    );

    return undef unless $self->is_active;

    # update exchange shipment status & log
    my $guard = $self->result_source->schema->txn_scope_guard;

    $self->set_cancelled( $operator_id );

    # Cancel shipment items belonging to exchange
    foreach my $item ( $self->shipment_items ) {
        next unless $item->can_cancel;

        die sprintf(
            "Can only refuse item if it has a status of 'Selected' (shipment item %d is in '%s').",
            $item->id, $item->shipment_item_status->status
        ) if $only_allow_selected_items && !$item->is_selected;

        $item->cancel({
            operator_id => $operator_id,
            customer_issue_type_id => $customer_issue_type_id,
            do_pws_update => $do_pws_update,
            pws_action_id => $PWS_ACTION__CANCELLATION,
            notes => $notes,
            stock_manager => $stock_manager,
        });
    }

    # We don't need to do anything else unless we're dealing with a sample
    if ($self->is_sample_shipment()) {

        # For sample shipments we need to cancel the stock_transfer too
        my $stock_transfer = $self->stock_transfer
            or die 'No stock transfer found for sample shipment';
        $stock_transfer->set_cancelled;

        # Send emails to warehouse_samples and stockadmin if we are cancelling
        # due to a stock discrepancy
        if ( $customer_issue_type_id == $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY ) {
            send_email(
                config_var('Email', 'xtracker_email'),
                config_var('Email', 'xtracker_email'),
                $_,
                $stock_transfer->channel->business->name. " Stock Discrepancy for sample shipment",
                sprintf(
                    "Sample shipment (%s) and sample sku (%s) have been cancelled due to insufficient available stock",
                    $self->id(), $stock_transfer->variant->sku
                )
            ) for map { config_var('Email', $_) } qw{warehouse_samples_email stockadmin_email};
        }
    }

    $guard->commit;

    return $self;
}

=head2 set_cancelled( $operator_id )

A wrapper around C<< $self->update_status >> that update the status of this
shipment to B<Cancelled>.

=cut

sub set_cancelled {
    my ( $self, $operator_id ) = @_;
    $self->update_status($SHIPMENT_STATUS__CANCELLED, $operator_id);
}

=head2 set_lost( $operator_id )

A wrapper around C<< $self->update_status >> that update the status of this
shipment to B<Lost>.

=cut

sub set_lost {
    my ( $self, $operator_id ) = @_;
    $self->update_status($SHIPMENT_STATUS__LOST, $operator_id);
}

=head2 clear_carrier_automation_data

This clears any data returned by the automation process such as Outward/Return
AWB's and Box Tracking Numbers and Label Images

=cut

sub clear_carrier_automation_data {
    my $self    = shift;

    $self->update( {
            outward_airway_bill => 'none',
            return_airway_bill  => 'none',
        } );
    if ( $self->shipment_boxes->count() ) {
        $self->shipment_boxes->update( {
                            tracking_number         => undef,
                            outward_box_label_image => undef,
                            return_box_label_image  => undef,
                        } );
    }

    return;
}

=head2 customer_details

Returns a HashRef with the details of the shipment's customer.

=cut

sub customer_details {
    my $self = shift;
    my $shipment_address = $self->shipment_address;
    # we need to look up the country code
    my $schema = $self->result_source->schema;
    my $country_code = $schema->resultset('Public::Country')
        ->search(
            { country => { 'ILIKE' => $shipment_address->country } }
        )
        ->first
        ->code
    ;

    my $customer_details = {
        Name                => $shipment_address->first_name . q{ } . $shipment_address->last_name,
        CompanyName         => $shipment_address->first_name . q{ } . $shipment_address->last_name,
        AttentionName       => $shipment_address->first_name . q{ } . $shipment_address->last_name,
        PhoneNumber         => (
               $self->telephone
            || $self->mobile_telephone
        ),
        EMailAddress        => $self->email,
        Address => {
            AddressLine1        => $shipment_address->address_line_1,
            AddressLine2        => $shipment_address->address_line_2,
            AddressLine3        => $shipment_address->address_line_3,
            City                => $shipment_address->towncity,
            StateProvinceCode   => $shipment_address->county,
            PostalCode          => $shipment_address->postcode,
            CountryCode         => $country_code,
        },
    };

    return $customer_details;
}

=head2 shipper_details

Returns a hash of the shipper's details.

=cut

sub shipper_details {
    my $self = shift;
    # the bulk of the information
    my $dc_info = config_section('DistributionCentre');
    my $dc_address = dc_address($self->get_channel);

    # we need to look up the country code
    my $schema = $self->result_source->schema;
    my $country_code = $schema->resultset('Public::Country')->search({
        country => { 'ILIKE' => $dc_address->{country} }
    })->first->code;

    # business information (for phone number)
    my $company_info = config_section(
          'Company_'
        . $self->shipping_account->channel->business->config_section
    );
    # so we can include the shipping email address
    my $email_info = config_section(
          'Email_'
        . $self->shipping_account->channel->business->config_section
    );

    my $shipper_details = {
        Name                => $self->shipping_account->channel->business->name,
        CompanyName         => $self->shipping_account->channel->business->name,
        AttentionName       => $dc_info->{contact},
        PhoneNumber         => $company_info->{ca_tel},
        EMailAddress        => $email_info->{shipping_email},
        Address => {
            AddressLine1        => $dc_address->{addr1},
            #AddressLine2        => $dc_info->{addr2},      # don't need to repeat Long Island City
            City                => $dc_info->{ups_city} // $dc_address->{city},
            StateProvinceCode   => $dc_address->{addr3},
            PostalCode          => $dc_address->{postcode},
            CountryCode         => $country_code,
        },
    };

    return $shipper_details;
}

=head2 carrier

Returns a DBIC row for the shipment's carrier.

=cut

sub carrier {
    my $self = shift;
    return $self->shipping_account->carrier;
}

=head2 variants

Returns a DBIC resultset of variants related to this shipment.

=cut

sub variants {
    my ($self) = @_;

    $self->shipment_items->related_resultset('variant');
}

=head2 order

Returns a DBIC row for this shipment's order if it has one.

=cut

sub order {
    my $join = $_[0]->link_orders__shipment;
    return unless $join;
    return $join->order;
}

=head2 stock_transfer

Returns a DBIC row for this shipment's stock transfer if it has one.

=cut

sub stock_transfer {
    # This needs to use link_stock_transfer__shipments
    my $join = $_[0]->link_stock_transfer__shipment;
    return unless $join;
    return $join->stock_transfer;
}

=head2 get_channel

Return a DBIC row for the channel this shipment is on.

Samples don't have an order - they use "stock_transfer".

=cut

sub get_channel {
    my $self = shift;
    return $self->order ? $self->order->channel
                        : $self->stock_transfer->channel;
}

=head2 stock_status_for_iws

Returns the stock status for iws... might need some revision, looks like it's
been ported.

=cut

sub stock_status_for_iws {
    my ($self) = @_;

    my $flow_status;

    if ($self->is_standard_class ||
        $self->is_reshipment ||
        $self->is_exchange ||
        $self->is_replacement_class ){
        $flow_status = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    }
    elsif ($self->is_transfer_shipment){
        # yes, 'main', because we only ever transfer main stock
        # even for sample shipments
        $flow_status = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    } else {
        # SHIPMENT_CLASS__SAMPLE, SHIPMENT_CLASS__PRESS, SHIPMENT_CLASS__RTV_SHIPMENT statuses
        # are all either deprecated or were never really used
        die sprintf 'Shipment item %d: Inappropriate, invalid or unknown status for picking : %d',
            $self->id, $self->shipment_class_id;
    }
    return $self->result_source->schema->resultset('Flow::Status')->find(
        $flow_status
    )->iws_name();
}

=head2 dispatched_date

Returns the date when the shipment was dispatched.

=cut

sub dispatched_date {
    my ($self) = @_;

    my $log = $self->shipment_status_logs->search({
      shipment_status_id => $SHIPMENT_STATUS__DISPATCHED
    })->first;

    return $log->date if $log;
}

=head2 return_cutoff_date

Returns the return cutoff date for this shipment.

=cut

sub return_cutoff_date {
    my($self) = @_;

    my $date = $self->dispatched_date;
    return unless $date;

    my $dt = $date->clone->truncate(to => 'day');

    # some fake shipping accounts have NULL cutoff days, let's approximate "+Inf"
    $dt->add( days => $self->shipping_account->return_cutoff_days || 900,
              hours => 23,
              minutes => 59,
              seconds => 59 );

}

=head2 tracking_uri

Returns the carrier's uri to track this shipment if it has one.

=cut

sub tracking_uri {
    my($self) = @_;
    my $token = $self->outward_airway_bill;

    if ($token eq 'none') {
        return '';
    }

    my $uri = $self->shipping_account->carrier->tracking_uri || '';

    $uri =~ s/<TOKEN>/$token/g;
    return $uri;
}

=head2 return_item_from_primary_return

Returns the return item from the original return (what?).

=cut

sub return_item_from_primary_return {
   my($self,$id) = @_;

   my $return = $self->returns->not_cancelled->first;

   if ($return) {
      return $return->return_item_from_shipment_item($id);
   }

   return;
}

=head2 list_picking_print_docs( [$rollout_phase] )

Returns a list of print docs associated with this shipment which should be
printed at the picking phase in the Invar Warehouse Management system (IWS)
or PRL.

The documents which can be printed here are:

=over

=item Address Card (for premier shipments)

=item MrP Sticker

=item Gift message

=back

=cut

sub list_picking_print_docs {
    my $self = shift;

    my $iws_phase = config_var('IWS', 'rollout_phase') || 0;
    my $prl_phase = config_var('PRL', 'rollout_phase') || 0;
    my @doctypes;

    # We only print docs at picking if we're using either IWS or PRLs, because
    # otherwise the picking is done within XT, and XT itself doesn't do any
    # printing during picking.
    unless ($iws_phase || $prl_phase) {
        return @doctypes;
    }
    # (Historical note: With IWS, printing at picking didn't happen until IWS
    # phase 2, but we're never planning to switch back to phase 1 so there's
    # no need to check specific IWS phase values any more.)

    # With PRLs, printing only currently happens at picking when there's a
    # Dematic allocation involved, because other PRLs don't have the required
    # printers to do the pick documents. (DCA-1707 covers cleaning this up.)
    if ($prl_phase) {
        # Look for Dematic allocations.
        # TODO: check that we don't count dematic allocations
        # containing only cancelled items
        my $dematic_allocations = $self->allocations->search({
            prl_id => $PRL__DEMATIC,
        });
        # If there aren't any matching Dematic allocations, we can't expect
        # a tote containing printdocs to come out of there.
        unless ($dematic_allocations->count()) {
            return @doctypes;
        }
    }

    # Premier address card
    if (
        $self->is_premier &&
        !$self->is_transfer_shipment ){
        push @doctypes, 'Address Card';
    }

    # Mr Porter stickers
    if (
        $self->stickers_enabled &&
        $self->order->sticker
    ) {
        push @doctypes, 'MrP Sticker'
    }

    # Gift messages
    my $has_gift_messages = $self->has_gift_messages();

    my $automated_gift_messages_configured_for_channel = defined(config_var(
        'GiftMessageImageGenerator',
        $self->get_business->config_section
    ));

    my $gift_messages_enabled = !config_var('GiftMessages', 'disable_automatic_gift_messages');

    if (
        $gift_messages_enabled &&
        $has_gift_messages &&
        $automated_gift_messages_configured_for_channel
    ) {
        push @doctypes, 'Gift Message';
    }

    return @doctypes;
}

=head2 picking_print_docs_info( )

Returns the same list as C<< $self->list_picking_print_docs >>, except with
more information - like the content of the print docs, and if it's been qc
failed.

As a useful side effect, also cleans out all qc failures for which the
print_doc is no longer required.

=cut

sub picking_print_docs_info {
    my $self = shift;

    my @docs = $self->list_picking_print_docs();

    # clean out unneeded shipment_extra_item rows
    $self->shipment_extra_items->search({item_type => { -not_in => \@docs}})->delete;

    # turn into hash, keyed on a whitespace stripped version of the document name
    my %docs;
    @docs{map {s/\s//; $_} @docs} = map { fullname => $_,
                                          %{$self->picking_print_doc_info($_)} }, @docs;

    return \%docs;
}

=head2 picking_print_doc_info( $document )

For a given picking print document, returns some basic information for display

=cut

sub picking_print_doc_info {
    my ($self, $document) = @_;

    my $qc = $self->shipment_extra_items->search({item_type => $document})->first;
    my $info = {
        is_qc_failed => $qc ? 1 : 0,
        qc_failure_reason => $qc ? $qc->qc_failure_reason : '',
        qc_packer_name => $qc && $qc->operator ? $qc->operator->name : ''
    };
    if ($document eq 'Address Card'){
        my $sa = $self->shipment_address;
        $info->{description} = join "\n", ( $sa->first_name . ' ' . $sa->last_name,
                                            $sa->address_line_1,
                                            $sa->address_line_2,
                                            $sa->address_line_3,
                                            $sa->towncity,
                                            $sa->county,
                                            $sa->postcode,
                                            $sa->country );
    } elsif ($document eq 'MrP Sticker') {
        $info->{description} = $self->order->sticker.' (quantity: '.$self->shipment_items->count().')';
    } elsif ($document eq 'Gift Message') {

        try {
            $info->{gift_messages} = $self->get_gift_messages();
        } catch {
            xt_logger("Unable to get gift image link: $_");
            $info->{gift_messages} = [];
        };

    } else {
        $info->{description} = "Document type '$document' not recognised. No information could be retrieved.";
    }
    return $info;
}

=head2 print_gift_messages (printer)

Prints the gift messages for the shipment.
May throw an exception if (say) a gift message can't
render itself in the net-a-porter font which it talks
to the front-end about.

If no exception is thrown, the function is considered
sucessful.

=cut

sub print_gift_messages {
    my ($self, $printer) = @_;

    my $gift_messages = $self->get_gift_messages();

    foreach my $gift_message (@$gift_messages) {
        $gift_message->print_gift_message($printer);
    }

}

=head2 print_gift_message_warnings (printer)

Print a bunch of gift message warnings for the shipment

=cut

sub print_gift_message_warnings {
    my ($self, $printer) = @_;

    my $gift_messages = $self->get_gift_messages();

    foreach my $gift_message (@$gift_messages) {
        $gift_message->print_gift_message_warning($printer);
    }

}

=head2 can_automate_gift_message

Returns a boolean denoting if the gift message can be automated.
Factors involved include if some part of the shipment is going
through the pick station (iws_phase == 2 || prl_phase == 1), that
an allocate with the dematic PRL has made, there is a gift message
actually present and if a configuration value doesn't explicitly
disable the feature.

=cut

sub can_automate_gift_message {
    my $self = shift;

    my $print_jobs = $self->picking_print_docs_info();
    return (exists($print_jobs->{GiftMessage}));
}

=head2 address_card_printed

Looks in the print log to see if we have apparently already printed this
address card.  Returns the number of log lines it can find for 'Address Card'
for this shipment.

=cut

sub address_card_printed {
    return shift->shipment_print_logs->search({
            document    => 'Address Card'
        })->count;
}


=head2 generate_dgn_paperwork( [{printer => $printer_name, copies => $copies}] )

Generate Dangerous Goods Note if a shipment contains Hazmat LQ item.
It is only for DC1. The note is generated during Labelling process

=cut

sub generate_dgn_paperwork {
    my ( $self, $print_args ) = @_;

    my $printer = $print_args->{printer} or return;
    my $copies  = $print_args->{copies};

    my $session = XTracker::Session->session;

    try {
      my $dgn = XTracker::Document::DangerousGoodsNote->new(
          shipment_id   => $self->id,
          operator_name => $session->{operator_name},
      );

      create_document( $dgn->basename, $dgn->template_path, $dgn->gather_data );

      my $printer_info = get_printer_by_name( $printer );
      if ( %{$printer_info||{}} ) {
          print_document( $dgn->basename, $printer_info->{lp_name}, $copies );

          # Log document in DB
          $dgn->log_document($printer_info->{name});
      }
    } catch {
        die "Couldn't create DGN document: $_";
    };

    return;
}

=head2 generate_return_proforma( [{printer => $printer_name, copies => $copies}] )

This sub will check for the existence of the relevant return proforma file,
and if it doesn't exist it will recreate it.  If it's passed a printer name
and the number of copies to print it will do so. If there is no entry for the
return proforma of the shipment in the Shipment Print Log table, it will add
one.

=head3 For EN-2382:

Stopped showing GBP & USD on DC1's version of the document and only showed GBP
for DC1 unless the Order's currency was different to the DC's in which case
this value was also shown. For DC2 only USD is ever shown which was how it
worked previously.

=cut

sub generate_return_proforma {
    my ( $self, $print_args ) = @_;

    # We can return unless we want to print stuff ( and log it )
    my $printer = $print_args->{printer};
    my $copies  = $print_args->{copies};

    return
        unless $self->requires_return_proforma;

    try {
      my $return_proforma = XTracker::Document::ReturnProforma
          ->new( shipment_id => $self->id );

      create_document(
          $return_proforma->basename,
          $return_proforma->template_path,
          $return_proforma->gather_data
      );

      return unless $printer;

      my $printer_info = get_printer_by_name( $printer );
      if ( %{$printer_info||{}} ) {
          print_document( $return_proforma->basename, $printer_info->{lp_name}, $copies );

          $return_proforma->log_document($printer_info->{name});
      }
    } catch {
      die "Couldn't create document: $@";
    };

    return;
}

=head2 requires_return_proforma: Bool

There are products that do not require
return proforma, like vouchers for example.
This method check if the current shipment
requires return proforma

=cut

sub requires_return_proforma {
    my $self = shift;

    my $returnable_items = grep { $_->display_on_returns_proforma }
        $self->non_cancelled_items->all;

    return !!$returnable_items;
}



=head2 matchup_sheet_shipment_class ()

Warehouse operators refer to what comes from the shipment_type table as
shipment class in various places. For display on the matchup sheet, they
want to see the shipment_type, but with a special exception for Canada.

=cut

sub matchup_sheet_shipment_class {
    my ($self) = @_;

    if ($self->shipment_address->country eq 'Canada') {
        return 'Canada Express';
    }

    return $self->shipment_type->type;
}


=head2 calculate_shipping( [$currency_code] )

Calculate the shipping for this shipment, rounded to the nearest .01.

=cut

sub calculate_shipping {
    my ( $self, $currency_code ) = @_;

    # Set exchange rate to 1 unless inputted a currency code
    my $exchange_rate
        = $currency_code ? $self->get_conversion_rate_to( $currency_code )
        : 1
        ;

    my $shipping = $self->shipping_charge * $exchange_rate;

    # Remove tax from shipping if required
    my $country = $self->shipment_address->country_table;
    if ( $country ) {
        my $country_tax_rate = $country->country_tax_rate;
        if ( $country_tax_rate and $country_tax_rate->rate > 0 ) {
            my $shipping_tax = $shipping
                             - ( $shipping
                               / ( 1 + $country_tax_rate->rate )
                             );
            $shipping = $shipping - $shipping_tax;
        }
    }
    return nearest( .01, $shipping );
}

=head2 total_tax( [$currency_code] )

Return the total tax for this shipment.

=cut

sub total_tax {
    my ( $self, $currency_code ) = @_;
    return $self->_total_value('tax', $currency_code);
}

=head2 total_price( [$currency_code] )

Return the total price for this shipment.

=cut

sub total_price {
    my ( $self, $currency_code ) = @_;
    return $self->_total_value('unit_price', $currency_code);
}

=head2 total_customs_value( )

Return the total customs value for shipment.

This is required for display on air waybill labels and is calculated by:
Adding shipment item unit prices plus shipping cost
Note that physical vouchers have a nominal value of 1 (in the currency of the order)
and promotional items are not included.

=cut

sub total_customs_value {
    my ( $self, ) = @_;

    my $total_value = 0;

    my @shipment_items = $self->non_cancelled_items->all;

    foreach my $item ( @shipment_items ) {
        next if $item->is_virtual_voucher;
        if ( $item->is_physical_voucher ) {
            $total_value += 1;
        }
        else {
            $total_value += $item->unit_price;
        }
    }
    $total_value += $self->shipping_charge;
    return $total_value;
}

=head2 total_duty( [$currency_code] )

Return the total_duty for this shipment.

=cut

sub total_duty {
    my ( $self, $currency_code ) = @_;
    return $self->_total_value('duty', $currency_code);
}

sub _total_value {
    my ( $self, $column_name, $currency_code ) = @_;

    # Set exchange rate to 1 unless inputted a currency code
    my $exchange_rate
        = $currency_code ? $self->get_conversion_rate_to( $currency_code )
        : 1
        ;

    my $total_value = 0;
    my @shipment_items = $self->non_cancelled_items->all;
    map { $total_value += nearest( .01, $_->$column_name * $exchange_rate ) }
        @shipment_items;
    return $total_value;
}

=head2 get_conversion_rate_to( [$currency_code] )

Return the conversion rate for this order to the given currency code

=cut

sub get_conversion_rate_to {
    my ( $self, $currency_code ) = @_;
    return $self->order->currency->conversion_rate_to( $currency_code );
}

=head2 total_weight

Returns the total weight of the shipment rounded to the nearest gram.

=cut

sub total_weight {
    my ( $self, ) = @_;
    my @shipment_items = $self->non_cancelled_items->all;
    my $total_weight = 0;
    map {
        $total_weight += nearest(
            .001,
            (
                # find out if it's a Product Variant of Voucher Variant
                defined $_->variant
                ? $_->variant->product->shipping_attribute->weight
                : $_->voucher_variant->product->weight
            )
        )
    } @shipment_items;
    return $total_weight;
}

=head2 total_volumetric_weight

Returns the total volumetric weight of the shipment rounded to the nearest gram.

=cut

sub total_volumetric_weight {
    my ( $self, ) = @_;
    my @shipment_boxes = $self->shipment_boxes;
    my $total_volumetric_weight = 0;
    map {
        $total_volumetric_weight += nearest(
            .001, ( $_->box->volumetric_weight )
        )
    } @shipment_boxes;
    return $total_volumetric_weight;
}


=head2 get_sales_invoice

Returns the original sales invoice. There can be multiple of these in cases of
shipments updated after packing - this one always returns the first one
ordered by id (relies on C<get_invoices> returning these sorted by id).

=cut

sub get_sales_invoice {
    return $_[0]->get_invoices->slice(0,0)->single;
}

=head2 get_invoices

Returns all the renumerations linked to this shipment of class 'Order' ordered
by id.

=cut

sub get_invoices {
    my ( $self ) = @_;
    my $renumerations = $self->renumerations;

    my $me = $renumerations->current_source_alias;
    return $renumerations->search(
        { "$me.renumeration_class_id" => $RENUMERATION_CLASS__ORDER },
        { "$me.order_by" => 'id'},
    );
}

=head2 payment_renumerations

Returns renumerations linked to this order of class 'Card Debit',

=cut

sub payment_renumerations {
    my ( $self ) = @_;
    my $renumerations = $self->renumerations;
    my $me = $renumerations->current_source_alias;
    return $renumerations->search_rs(
        { "$me.renumeration_type_id" => $RENUMERATION_TYPE__CARD_DEBIT },
        { "$me.order_by" => 'id'},
    );
}

=head2 refund_renumerations

Returns renumerations linked to this order of class 'Card Refund' or 'Store
Credit'.

=cut

sub refund_renumerations {
    my ( $self ) = @_;
    my $renumerations = $self->renumerations;
    my $me = $renumerations->current_source_alias;
    return $renumerations->search_rs(
        { "$me.renumeration_type_id" =>
          { -in => [ $RENUMERATION_TYPE__CARD_REFUND, $RENUMERATION_TYPE__STORE_CREDIT ] }
        },
        { "$me.order_by" => 'id'},
    );
}

=head2 apply_SLAs

Request and store an SLA cutoff and WMS priority settings for this shipment

=cut

sub apply_SLAs {
    my ($self) = @_;

    # Ensure 'date' field has been populated (it is initially populated
    # in the db via 'default' and therefore doesn't appear in this object)
    $self->discard_changes();

    # Exchange shipments should not be assigned an SLA until the original shipment
    # has been returned
    return if ($self->is_exchange_class && $self->is_awaiting_return);

    my ($sla_cutoff_datetime, $wms_initial_pick_priority, $wms_deadline_datetime,
        $wms_bump_pick_priority, $wms_bump_deadline_datetime);

    if ($self->use_sos_for_sla_data()) {
        try {
            ($sla_cutoff_datetime, $wms_initial_pick_priority, $wms_deadline_datetime,
            $wms_bump_pick_priority, $wms_bump_deadline_datetime) = $self->get_sla_data();
        } catch {
            my $error = $_;

            $self->xtlogger->error(sprintf('SOS SLA request for Shipment %s failed: %s',
                $self->id(), $error));

            # If the call to SOS fails for some reason, we use the 'emergency' settings
            # to ensure the system can keep going...
            ($sla_cutoff_datetime, $wms_initial_pick_priority, $wms_deadline_datetime,
            $wms_bump_pick_priority, $wms_bump_deadline_datetime)
                = $self->get_emergency_sla_data();

            # But we should send an e-mail alert to let people know that something has
            # gone wrong
            try {
                send_internal_email(
                    to => $self->get_config_var('SOS', 'alert_emails_to'),
                    subject => sprintf('SLA call to SOS failed for Shipment: %s', $self->id() ),
                    from_file => {
                        path => $SOS_ALERT_EMAIL_TEMPLATE,
                    },
                    stash => {
                        shipment                    => $self,
                        error_message               => "$_",
                        sla_cutoff_datetime         => $sla_cutoff_datetime,
                        wms_initial_pick_priority   => $wms_initial_pick_priority,
                        wms_deadline_datetime       => $wms_deadline_datetime,
                        wms_bump_pick_priority      => $wms_bump_pick_priority,
                        wms_bump_deadline_datetime  => $wms_bump_deadline_datetime,
                        template_type               => 'email',
                    }
                );
            } catch {
                $self->xtlogger->error(sprintf('Error sending sos alert e-mail: %s', $_));
            };
        };
    } else {
        # Not using SOS, so we use the 'old' way
        $sla_cutoff_datetime = $self->get_sla_cutoff_dbic_value();
    }

    $self->update({
        sla_cutoff                  => $sla_cutoff_datetime,
        sla_priority                => $self->get_sla_priority(),
        wms_initial_pick_priority   => $wms_initial_pick_priority,
        wms_deadline                => $wms_deadline_datetime,
        wms_bump_pick_priority      => $wms_bump_pick_priority,
        wms_bump_deadline           => $wms_bump_deadline_datetime,
    });

    # This prevents subsequent DBIx::Class requests for sla_cutoff
    # returning scalar reference and makes them actually retrieve data
    # from db
    $self->discard_changes;

    return;
}

=head2 get_sla_cutoff_dbic_value

Return sla_cutoff value for use in DBIC ->update

=cut

sub get_sla_cutoff_dbic_value {
    my $self = shift;

    if($self->nominated_dispatch_time()) {
        return $self->get_nominated_day_sla_cutoff_time();
    }

    my $sla_interval = $self->get_sla_cutoff;
    return \"CURRENT_TIMESTAMP + interval '$sla_interval'";
}

=head2 get_nominated_day_sla_cutoff_time() : DateTime $sla_cutoff_time

Return $sla_cutoff_time when the Shipment has a Nominated Day.

This requires there to be a nominated_dispatch_time on the Shipment.

The cutoff time is the nominated_dispatch_time - 2h, but at least 1h from
now.


=head3 ASCII-ART

Time (Now) moves to the right and catches up with the Nominated
Dispatch time as the examples progress below

 x is the SLA cutoff_time
 | are other times


Dispatch in Far Future:
                        x <--2h-- | Nominated Dispatch
   Now | --1h--> |


Dispatch in Near Future:
                        x <--2h-- | Nominated Dispatch
        Now | --1h--> |

Dispatch inside minimum window
                        | <--2h-- | Nominated Dispatch
             Now | --1h--> x

Dispatch really urgent, but we give the staff 1h SLA anyway
                        | <--2h-- | Nominated Dispatch
                            Now | --1h--> x

Dispatch too late, should't be shipped at all really, it'll reach the
customer at the wrong time
                        | <--2h-- | Nominated Dispatch
                                  Now | --1h--> x

=cut

sub get_nominated_day_sla_cutoff_time {
    my $self = shift;

    my $sla_cutoff_time      = $self-> default_nominated_cutoff_time();
    my $earliest_cutoff_time = $self->earliest_nominated_cutoff_time();

    if( $sla_cutoff_time < $earliest_cutoff_time ) {
        return $earliest_cutoff_time;
    }

    return $sla_cutoff_time;
}

sub default_nominated_cutoff_time {
    my $self = shift;

    my $sla_cutoff_time = $self->nominated_dispatch_time->clone;
    my $buffer_minutes = config_var(
        "NominatedDay",
        "default_sla_duration_before_dispatch__minutes",
    );
    $sla_cutoff_time->subtract(minutes => $buffer_minutes);
    $self->try_to_set_time_zone($sla_cutoff_time);

    return $sla_cutoff_time;
}

sub earliest_nominated_cutoff_time {
    my $self = shift;

    my $minimum_minutes = config_var(
        "NominatedDay",
        "minimum_sla_duration_before_dispatch__minutes",
    );
    my $earliest_cutoff_time = DateTime->now()->add(minutes => $minimum_minutes);
    $self->try_to_set_time_zone($earliest_cutoff_time);

    return $earliest_cutoff_time;
}

sub try_to_set_time_zone {
    my ($self, $datetime) = @_;
    my $order = $self->order or return;
    $datetime->set_time_zone( $order->channel->timezone );
}

sub get_sla_cutoff {
    my ( $self ) = @_;

    my $get_interval_type = sub {
        # Non-order shipments use the transfer SLA interval
        return 'transfer_sla_interval'
            if $self->is_transfer_shipment
            || $self->is_rtv_shipment;

        # Replacements have premier SLAs except for staff that have standard
        return ( $self->is_staff_order
               ? 'standard_sla_interval'
               : 'premier_sla_interval'
        ) if $self->is_replacement_class;

        # When exchange shipments are first created we give them a very high
        # SLA so we don't infringe it before it's even been processed.
        return 'exchange_creation_sla_interval'
            if $self->is_exchange_class && $self->is_awaiting_return;

        my @items = $self->shipment_items->all;
        my $price_adjust_count = grep {
            $_->link_shipment_item__price_adjustment
        } @items;

        return $self->is_staff_order        ? 'staff_sla_interval'    # All staff orders
            : $self->is_premier             ? 'premier_sla_interval'  # All premier orders
            : $price_adjust_count < @items  ? 'standard_sla_interval' # There is at least one full priced item
            :                                 'sale_sla_interval';    # Otherwise it's a sale order
    };
    my $interval_type = $get_interval_type->();

    my $order = $self->order;
    my $config_group_rs
        = $self->result_source->schema->resultset('SystemConfig::ConfigGroup');
    # If we have an order associated with this shipment, check if we have a
    # channel-specific override SLA - in all other cases use the default SLAs
    my $config_group
        = $order && $config_group_rs->search({
            name => "dispatch_slas", channel_id => $order->channel_id,
        })->slice(0,0)->single->$interval_type
     || $config_group_rs->search({ name => 'default_slas'
         })->slice(0,0)->single->$interval_type;
}

sub get_sla_priority {
    my ( $self ) = @_;
    my $order = $self->order;
    return (
        ($order && $order->customer->is_category_staff)
        || $self->is_transfer_shipment
        || !$self->is_premier
    ) ? 2 : 1;
}

=head2 is_pick_complete

Check if all shipment items have been picked, exclude any for Virtual
Vouchers. This is the equivalent of
C<XTracker::Database::Distribution::check_pick_complete>

=cut

sub is_pick_complete {
    my $self    = shift;

    # assume everything has been picked
    my $complete    = 1;

    my $ship_items  = $self->shipment_items;
    while ( my $item = $ship_items->next ) {
        # ignore if a Virtual Voucher
        next        if ( $item->is_virtual_voucher );

        if ( number_in_list($item->shipment_item_status_id,
                            $SHIPMENT_ITEM_STATUS__NEW,
                            $SHIPMENT_ITEM_STATUS__SELECTED,
                        ) ) {
            $complete   = 0;
            last;
        }
    }

    return $complete;
}

=head2 total_spent_by_card

This sub will return the total amount spent by card for this shipment.

=cut

sub get_total_spent_by_card {
    return $_[0]->get_sales_invoice->grand_total;
}

=head2 total_spent_by_store_credit

This sub will return the total amount spent by store credit for this shipment.

=cut

sub get_total_spent_by_store_credit {
    return abs($_[0]->get_sales_invoice->store_credit);
}

=head2 get_store_credit_refund

Returns the total refunds returned to store credit.

=head3 NOTE

This also includes shipping.

=cut

sub get_store_credit_refund {
    shift->_get_refund_for_renumeration_type( $RENUMERATION_TYPE__STORE_CREDIT );
}

=head2 get_card_refund

Returns the total refunds returned to the customer's card.

=cut

sub get_card_refund {
    shift->_get_refund_for_renumeration_type( $RENUMERATION_TYPE__CARD_REFUND );
}

sub _get_refund_for_renumeration_type {
    my ( $self, $renumeration_type_id ) = @_;
    croak 'You must provide a $renumeration_type_id'
        unless $renumeration_type_id;
    my $total_refund = 0;
    $total_refund += $_->total_value + $_->shipping
        for $self->renumerations
                 ->search({renumeration_type_id => $renumeration_type_id})
                 ->all;
    return $total_refund;
}

=head2 is_shipment_packed

Returns a true value if any of the shipment's items have been packed. This is
DBIC version of C<XTracker::Database::Shipment::check_shipment_packed>.

=cut

sub is_shipment_packed {
    my ( $self ) = @_;
    my @status_id = $self->shipment_items->get_column('shipment_item_status_id')->all;
    foreach ( @status_id ) {
        return 1 if ( $_ == $SHIPMENT_ITEM_STATUS__PACKED
                   || $_ == $SHIPMENT_ITEM_STATUS__DISPATCHED );
    }
    return 0;
}

=head2 list_class

The class (sale, ftbc, priority, staff, transfer) to display on picking sheets and packing screens

=cut

sub list_class {
    my ($self) = @_;

    my $order = $self->order;
    my $customer = $order ? $order->customer : undef;

    return $self->is_transfer_shipment                  ? 'Stock Transfer'
         : $self->is_sample_class                       ? 'Sample Transfer'
         : $self->is_staff_order                        ? 'Staff Order'
         : $self->shipping_account->name eq 'FTBC'      ? 'FTBC Order'
         : $self->is_sale_order                         ? 'Sale Order'
         : $customer && $customer->category->fast_track ? 'Priority Order'
         :                                                'Customer Order'
}

=head2 count_sale_items

Return the number of products in this shipment that are on sale.

=cut

sub count_sale_items {
    my ($self) = @_;

    my $ret=0;

    my $items= [$self->related_resultset('shipment_items')->all];
    for my $i (@$items) {
        ++$ret if $i->product->is_on_sale;
    }
    return $ret;
}

=head2 is_first_order

Checks if this shipment is the customer's first order.

=cut

sub is_first_order {
    my ($self) = @_;

    my $order=$self->order;
    if ($order && $order->count_related('order_flags',{ flag_id => $FLAG__1ST })) {
        return 1;
    }
    return 0;
}

=head2 is_sale_order

Checks if all the items in this shipment are on sale and it's not the
customer's first order.

=cut

sub is_sale_order {
    my ($self) = @_;

    if ($self->count_sale_items() == $self->count_related('shipment_items')
            && !$self->is_first_order) {
        return 1;
    }
    return 0;
}

=head2 is_staff_order

Checks if this shipment is part of a staff order.

=cut

sub is_staff_order {
    my ($self) = @_;

    my $order    = $self->order     or return 0;
    return $order->is_staff_order;
}

=head2 check_and_release_dates

Returns a hashref with dates for C<check> and C<release>.

=cut

sub check_and_release_dates {
    my ($self) = @_;

    my $held = $self->search_related('shipment_status_logs',{
        shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
    },{
        order_by => { -desc => 'date' },
        rows => 1,
    })->single;

    return {} unless $held;

    my $check_date = $held->date;

    my $released = $self->search_related('shipment_status_logs',{
        shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
    },{
        order_by => { -desc => 'date' },
        rows => 1,
    })->single;

    my $release_date = $released ? $released->date : undef;

    return { check => $check_date, release => $release_date }
}

=head2 fulfilment_or_shipping_notes

Returns an array of DBIC row objects for shipment notes that have types of
B<Fulfilment>, B<Shipping> or B<Quality Control>.

=cut

sub fulfilment_or_shipping_notes {
    my ($self) = @_;

    return $self->search_related('shipment_notes',{
        note_type_id => { -in => [
            $NOTE_TYPE__FULFILLMENT,
            $NOTE_TYPE__SHIPPING,
            $NOTE_TYPE__QUALITY_CONTROL
        ] }
    }, {
        order_by => { -asc => 'date' },
    })->all;
}

=head2 is_shipment_completely_packed

Returns TRUE if all of the Shipment Items have been Packed excluding items which have been cancelled.

=cut

sub is_shipment_completely_packed {
    my $self    = shift;

    my @items   = $self->shipment_items->all;
    foreach ( @items ) {
        if ( $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__PACKED
          && $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__DISPATCHED
          && $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
          && $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED ) {
            # if the status is not one of the above then it's not Packed
            return 0;
        }
    }

    return 1;
}

=head2 is_shipment_completely_picked

Returns TRUE if all of the Shipment Items have been Picked excluding items which have been cancelled.

=cut

sub is_shipment_completely_picked {
    my $self    = shift;

    my @items   = $self->shipment_items->all;
    foreach ( @items ) {
        if ( $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__PICKED
          && $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
          && $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED ) {
            # if the status is not one of the above then it's not Picked
            return 0;
        }
    }

    return 1;
}

=head2 is_virtual_voucher_only

Determines whether the shipment's items are all virtual Vouchers.

=cut

sub is_virtual_voucher_only {
    my $self    = shift;

    my @items   = $self->shipment_items->all;
    foreach my $item ( @items ) {
        if ( !$item->is_virtual_voucher
          && $item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
          && $item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED ) {
            return 0;
        }
    }

    return 1;
}

=head2 dispatch_virtual_voucher_only_shipment( $operator_id )

This dispatches a Virtual Voucher Only Shipment.

=cut

sub dispatch_virtual_voucher_only_shipment {
    my $self    = shift;
    my $op_id   = shift;

    if ( !defined $op_id ) {
        die "No Operator Id passed to XTracker::Schema::Result::Public::Shipment->dispatch_virtual_voucher_only_shipment";
    }

    my $retval  = 0;
    my $schema  = $self->result_source->schema;

    if ( $self->shipment_status_id == $SHIPMENT_STATUS__PROCESSING
      && $self->is_virtual_voucher_only
      && $self->is_shipment_completely_picked ) {

        # Firstly Take the money
        eval {
            process_payment( $schema, $self->id );
        };
        if ( my $err = $@ ) {
            # problem taking money
            # mark order for Credit Hold
            $retval = 0;
            $self->update_status( $SHIPMENT_STATUS__FINANCE_HOLD, $op_id );
            my $order   = $self->order;
            $order->update( { order_status_id => $ORDER_STATUS__CREDIT_HOLD } );
            $order->create_related( 'order_status_logs', {
                                            order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                            operator_id => $op_id,
                                            date => \"current_timestamp",
                                        } );
            # set a FLAG, if this already exists then create it again!
            $order->create_related( 'order_flags', {
                                            flag_id => $FLAG__VIRTUAL_VOUCHER_PAYMENT_FAILURE,
                                        } );
        }
        else {
            my @items   = $self->shipment_items->all;
            foreach ( @items ) {
                if ( $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                  && $_->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED ) {
                    # log shipment item as Packed for completeness
                    $_->create_related( 'shipment_item_status_logs', {
                                                                    shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED,
                                                                    operator_id => $op_id,
                                                            } );
                    $_->update_status( $SHIPMENT_ITEM_STATUS__DISPATCHED, $op_id );
                }
            }
            $self->update_status( $SHIPMENT_STATUS__DISPATCHED, $op_id );

            # send dispatch message to PWS
            # a lot of pain to seperate this from here as there
            # would be a lot of updates needing to take place
            # to a lot of Handlers
            my $amq = $self->msg_factory;
            $self->discard_changes;
            $amq->transform_and_send( 'XT::DC::Messaging::Producer::Orders::Update', { order => $self->order } );

            $retval = 1;
        }
    }

    return $retval;
}

=head2 dispatch( $operator_id )

Sets shipment and shipment items statuses to Dispatched, and logs it.

=cut

sub dispatch {
    my ($self, $operator_id) = @_;

    # Check the shipment status is what we're expecting
    if ($self->shipment_status_id == $SHIPMENT_STATUS__HOLD) {
        die "The shipment entered is currently ON HOLD.\n";
    } elsif ($self->shipment_status_id == $SHIPMENT_STATUS__DISPATCHED) {
        die "The shipment has already been dispatched.\n";
    } elsif ($self->shipment_status_id == $SHIPMENT_STATUS__CANCELLED) {
        die "The shipment has been cancelled.\n";
    } elsif ($self->shipment_status_id != $SHIPMENT_STATUS__PROCESSING) {
        die "The shipment is not in the correct status for dispatch.\n";
    }

    # Check all the shipment items are ok too
    foreach my $shipment_item ($self->shipment_items) {
        if ($shipment_item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__PACKED
                && $shipment_item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                && $shipment_item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED) {

            die "The shipment contains items which are not the correct status for dispatch.\n";
        }
    }

    # Premier shipments need an address card
    if ($self->shipment_type_id == $SHIPMENT_TYPE__PREMIER
            && $self->shipment_class_id != $SHIPMENT_CLASS__TRANSFER_SHIPMENT) {

        my $address_cards_printed = $self->shipment_print_logs->search({
            'document' => 'Address Card'
        })->count();

        if ($address_cards_printed == 0) {
            die "The shipment paperwork has not been printed, please check before dispatch.\n";
        }
    }

    # Shipment should be ok to dispatch if we've got this far
    $self->update({
        'shipment_status_id' => $SHIPMENT_STATUS__DISPATCHED,
    });
    $self->shipment_status_logs->create({
        'shipment_status_id' => $SHIPMENT_STATUS__DISPATCHED,
        'operator_id' => $operator_id
    });

    # Notify anyone who cares about stock levels
    $self->broadcast_stock_levels();

    foreach my $shipment_item (
        $self->shipment_items->not_cancelled->not_cancel_pending->all
    ) {
        $shipment_item->update({
            'shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__DISPATCHED,
        });
        $shipment_item->shipment_item_status_logs->create({
            'shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__DISPATCHED,
            'operator_id' => $operator_id
        });

    }

    # All containers are now empty
    foreach my $container ($self->containers) {
        $container->send_container_empty_to_prls();
    }

    return;
}

=head2 broadcast_stock_levels

=cut

sub broadcast_stock_levels {
    my $self = shift;

    # Look for any _distinct_ products in the shipment:
    my @products
    = $self->shipment_items->not_cancelled->not_cancel_pending
        ->related_resultset('variant')
        ->search_related('product',{},{distinct=>1});

    # Broadcast the stock levels
    foreach my $product ( @products ) {
        $product->broadcast_stock_levels;
    }

    # Look for any _distinct_ vouchers in the shipment
    my @vouchers
    = $self->shipment_items->not_cancelled->not_cancel_pending
        ->related_resultset('voucher_variant')
        ->search_related('product',{},{distinct=>1});

    # Broadcast the stock levels
    foreach my $voucher ( @vouchers ) {
        $voucher->broadcast_stock_levels;
    }

    return 1;
}

=head2 auto_pick_virtual_vouchers( $operator_id ) : picked_voucher_count

This calls a automatically "Pick's" any Virtual Voucher Shipment Items.

=cut

sub auto_pick_virtual_vouchers {
    my $self        = shift;
    my $operator_id = shift;

    croak "auto_pick_virtual_vouchers requires an operator id"
        unless defined $operator_id;

    my $count = 0;
    return $count unless $self->is_processing;

    my $item_rs = $self->shipment_items
        ->search({ voucher_variant_id => { '!=' => undef } });
    foreach my $item ( $item_rs->all ) {
        # If it's a virtual voucher and has a Code assigned 'Pick' it
        next unless $item->is_virtual_voucher;
        next unless $item->is_new;
        next unless defined $item->voucher_code_id;

        # Create a log for 'Selected' to keep things sane
        $item->create_related('shipment_item_status_logs', {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
            operator_id             => $operator_id,
        });
        # update the item's status
        $item->update_status( $SHIPMENT_ITEM_STATUS__PICKED, $operator_id );
        $count++;
    }
    return $count;
}


=head2 summarise_gift_message($length)

Return the first C<$length> characters of the gift message, followed by '[...]'

=cut

sub summarise_gift_message {
    my ( $self, $length ) = @_;
    $length ||= 20;

    my $gm_text = $self->gift_message;
    $gm_text =~ s/\n/ /g;  # remove whitespace.
    if (length($gm_text) > $length) {
        return substr($gm_text, 0, 20) . " [...]";
    } else {
        return $gm_text;
    }
}

=head2 has_vouchers

Returns a true value if the shipment has at least one voucher.

=cut

sub has_vouchers {
    my ( $self ) = @_;
    return 1
        if grep { defined $_ }
            $self->shipment_items->get_column('voucher_variant_id')->all;
    return;
}

=head2 print_sticker ($printer, $copies)

Prints personalised sticker for shipment at picking/packing time

=cut

sub print_sticker {
    my ( $self, $printer, $copies ) = @_;

    # ensure at least one print
    $copies = 1 unless $copies;

    # prevent blank stickers!
    return unless $self->order->sticker;

    $self->shipment_print_logs->create({
        document     => "MRP Sticker $copies copies",
        file         => $self->order->sticker,
        printer_name => $printer, # can be an IP or a hostname
    });

    print_mrp_sticker({
        text => $self->order->sticker,
        printer => $printer, # can be an IP or a hostname
        copies => $copies,
    });

    return 1; # success
}

=head2 stickers_enabled

Checks if shipment implements sticker printing

=cut

sub stickers_enabled {
    my ( $self ) = @_;
    return unless $self->order;
    my $channel = $self->order->channel;
    return 1 if $self->result_source->schema->resultset('SystemConfig::ConfigGroupSetting')
         ->config_var( "personalized_stickers", "print_sticker", $channel->id );
    return;
}

=head2 stickers_printed

Looks in the print log to see if we have apparently already printed these
stickers. Returns the number of log lines it can find for MRP stickers.

=cut

sub stickers_printed {
    return shift->shipment_print_logs->search({
            document    => { like => 'MRP Sticker%' }
        })->count;
}

=head2 container_ids

Returns a list of the container IDs that contain this shipment's items.

=cut

sub container_ids {
    my ($self) = @_;

    return uniq grep {defined $_} $self->shipment_items->get_column('container_id')->all;
}

=head2 packable_container_ids

Return a list of container ids with a status that implies they don't contain
superfluous or packing exception items.

=cut

sub packable_container_ids {
    my ($self) = @_;

    return $self->result_source->schema->resultset('Public::Container')->search(
        { 'id' => { -in => [ $self->container_ids ] },
          'status_id' => { -not_in => [$PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS,
                                       $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS]} },
        { distinct => 1 }
    )->get_column('id')->all;
}

=head2 containers

Return a resultset of container ids that contain this Shipment's
items.

=cut

sub containers {
    my ($self) = @_;

    my $container_rs = $self->result_source->schema->resultset('Public::Container');
    return $container_rs->search(
        { "me.id" => { -in => [ $self->container_ids ] } },
        { distinct => 1 }
    );
}

=head2 has_containers

Return a true value if any of the items are in a container.

=cut

sub has_containers {
    my $self = shift;
    return $self->container_ids > 0;
}

=head2 pack_status

Return a hashref summarising the status of this shipment.

=cut

sub pack_status {
    my ($self) = @_;

    my %results =(
        "notready" => 0,
        "ready" => 0,
        "packed" => 0,
        "assigned" => 0,
        "notassigned" => 0,
        "pack_complete" => 0,
    );

    my $rs=$self->related_resultset('shipment_items');
    while (my $ship_item = $rs->next) {
        next if $ship_item->is_virtual_voucher;

        if ( number_in_list($ship_item->shipment_item_status_id,
                            $SHIPMENT_ITEM_STATUS__NEW,
                            $SHIPMENT_ITEM_STATUS__SELECTED,
                        ) ) {
            $results{notready}++;
        }
        elsif ( $ship_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ) {
            $results{notready}++;
        }
        elsif ( $ship_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PICKED ) {
            $results{ready}++;
        }
        elsif ( number_in_list($ship_item->shipment_item_status_id,
                                 $SHIPMENT_ITEM_STATUS__PACKED,
                                 $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                 $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                                 $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                                 $SHIPMENT_ITEM_STATUS__RETURNED,
                             ) ) {
            $results{packed}++;
        }
        else {

        }

        ### item/box status
        if ($ship_item->shipment_box_id) {
            $results{assigned}++;
        }
        elsif ($ship_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKED) {
            $results{notassigned}++;
        }
    }

    if ( number_in_list($self->shipment_status_id,
                        $SHIPMENT_STATUS__FINANCE_HOLD,
                        $SHIPMENT_STATUS__HOLD,
                        $SHIPMENT_STATUS__RETURN_HOLD,
                        $SHIPMENT_STATUS__EXCHANGE_HOLD,
                        $SHIPMENT_STATUS__DDU_HOLD) ) {
        $results{on_hold} = 1;
    }
    elsif ( $self->shipment_status_id == $SHIPMENT_STATUS__CANCELLED ) {
        $results{cancelled} = 1;
    }

    if ( !$self->is_premier ) {
        if ( ( $self->outward_airway_bill ne 'none' && !$self->real_time_carrier_booking )
                 || ( $self->real_time_carrier_booking &&
                          number_in_list($self->shipment_status_id,
                                         $SHIPMENT_STATUS__DISPATCHED,
                                         $SHIPMENT_STATUS__CANCELLED,
                                         $SHIPMENT_STATUS__RETURN_HOLD,
                                         $SHIPMENT_STATUS__EXCHANGE_HOLD,
                                         $SHIPMENT_STATUS__LOST,
                                         $SHIPMENT_STATUS__DDU_HOLD,
                                         $SHIPMENT_STATUS__RECEIVED,
                                         $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD,
                                     ) ) ) {
            $results{pack_complete} = 1;
        }
    }

    return \%results;
}

=head2 items_by_sku( $sku )

Search this shipment's items for the given $sku.

=cut

sub items_by_sku {
    my ($self, $sku) = @_;

    my ($pid, $sid) = split(/-/, $sku);

    return $self->search_related('shipment_items',{
        -or => [
            { 'variant.product_id' => $pid, 'variant.size_id' => $sid },
            { 'voucher_variant.voucher_product_id' => $pid },
        ]
    },{
        join => [ 'variant','voucher_variant' ],
    });
}

=head2 qc_fail_shipment_extra_item

QC fails an extra item in the shipment.

=cut

sub qc_fail_shipment_extra_item {
    my ($self, $type, $reason, $operator_id) = @_;

    die "Must provide a shipment_extra_item type when qc failing it"
        unless defined $type && $type ne '';
    die "Must provide a qc failure reason when failing a shipment_extra_item"
        unless defined $reason && $reason ne '';
    die "Must provide an operator id when failing a shipment_extra_item"
        unless defined $operator_id && $operator_id =~ m/^\d+$/;

    $self->add_to_shipment_extra_items({
        item_type           => $type,
        qc_failure_reason   => $reason,
        operator_id         => $operator_id,
    });
}

=head2 qc_fix_shipment_extra_item

Fixes a previously qc failed extra item in the shipment.  If there's multiple
items of the same type found, just deletes one of them at random. No reason
why there should be > 1 for now though.

=cut

sub qc_fix_shipment_extra_item {
    my ($self, $type) = @_;

    die "Must provide a shipment_extra_item type to fix"
        unless defined $type && $type ne '';
    my $qc = $self->shipment_extra_items->search({item_type => $type})->first;
    return 0 unless $qc;
    $qc->delete;
}

=head2 fix_shipment_items_exception

Update the status of packing exception items in this shipment fo B<Picked>.

=cut

sub fix_shipment_items_exception {

    my ( $self, $operator_id ) = @_;

    my $pe_items = $self->packing_exception_items;
    my $dbh = $self->result_source->storage->dbh;

    while (my $item=$pe_items->next) {
        $item->created_related('shipment_item_status_logs', {
            shipment_item_status_id     => $SHIPMENT_ITEM_STATUS__PICKED,
            operator_id                 => $operator_id,
        });
    }

    $self->shipment_items->search_related('container')->update({
        status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
    });

    $pe_items->update( {
        shipment_item_status_id=> $SHIPMENT_ITEM_STATUS__PICKED,
        qc_failure_reason => undef,
    } );

    return;
}

=head2 is_awaiting_replacements

Returns true if the shipment is at packing exception and waiting for
replacements.

=cut

sub is_awaiting_replacements {
    my ($self,$iws_phase) = @_;

    return $iws_phase ?
          $self->is_at_packing_exception && $self->selected_items->count
        : $self->is_at_packing_exception && $self->unselected_items->count
;
}

=head2 is_being_replaced

Return a true value the shipment has containers with statuses of B<Packing
Exception> and B<Picked>.

=head3 NOTE

# terrible method name -- plz fix

=cut

sub is_being_replaced{
    my ($self) = @_;

    return 1 if  $self->containers->count({ status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS })
              && $self->containers->count({ status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS })
      ;
}

=head2 send_to_commissioner

Send this shipment's containers to commissioner.

=cut

sub send_to_commissioner {
    my $self = shift;

    $self->containers->send_to_commissioner;
}

=head2 is_on_hold

Checks if the shipment is on hold for any reason at all.

=cut

sub is_on_hold {
    my $self = shift;

    return number_in_list(
        $self->shipment_status_id,
        @{$self->result_source->resultset->hold_status_list}
    );
}

=head2 is_held

Check if the shipment has a status of 'Hold'.

=cut

sub is_held { shift->shipment_status_id == $SHIPMENT_STATUS__HOLD; }

=head2 relationships_for_signature

Always returns 'shipment_items'. Don't know what this does... look at
XTracker::Schema::Role::WithStateSignature.

=cut

sub relationships_for_signature {
    return 'shipment_items';
}

=head2 iws_stock_status

Until phase 3, IWS only deals with 'main' and 'dead', and we never ship
'dead'. So we always return 'main'.

=cut

sub iws_stock_status {
    return $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
}

=head2 iws_priority_class

This method returns the priority of a shipment so IWS know which shipments to
prepare first. Currently using C<sla_priority>, with a default of 13 (normal
customer shipment).

=cut

sub iws_priority_class {
    my ($self) = @_;

    my $prio = $self->sla_priority;
    if (!defined $prio) { $prio = 13 };
    return $prio;
}

=head2 does_iws_know_about_me

Has this shipment ever been sent to IWS? Roughly equivalent to "has any
physical item been selected up to now?".

=cut

sub does_iws_know_about_me {
    my ($self) = @_;

    return if $self->shipment_class_id == $SHIPMENT_CLASS__RE_DASH_SHIPMENT;

    my $count=0;

    for my $item ($self->shipment_items->all) {
        next if $item->is_virtual_voucher;
        next unless number_in_list(
            $item->shipment_item_status_id,
            $SHIPMENT_ITEM_STATUS__SELECTED,
            $SHIPMENT_ITEM_STATUS__PICKED,
            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
            $SHIPMENT_ITEM_STATUS__PACKED,
        );
        $count += $item->search_related('shipment_item_status_logs',{
            'shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__SELECTED,
        })->count;
    }

    return $count>0;
}

=head2 has_validated_address() : Bool

Returns true if the shipment's address has been validated successfully. Note
that this method I<doesn't> perform the validation, it only checks that the
shipment has already been validated successfully.

=cut

sub has_validated_address {
    my ($self) = @_;

    if ( $self->carrier_is_ups ) {
        # Multiply by 100 to avoid floating point comparison weirdness
        my $qrt = $self->ups_quality_rating_threshold * 100;
        my $avqr = ($self->av_quality_rating || 0) * 100;
        # If the shipment's address quality rating is >= to the channel's
        # threshold the address is valid
        return $avqr >= $qrt;
    }
    # DHL validation is slightly simpler - if we have a destination code it's
    # valid
    if ( $self->carrier_is_dhl ) {
        return !!$self->destination_code;
    }
    # We don't validate other carriers' addresses, so we just assume they passed
    return 1;
}

=head2 ups_quality_rating_threshold

Get the UPS quality rating threshold for this shipment.

=cut

sub ups_quality_rating_threshold {
    return get_ups_qrt( shift->get_channel->business->config_section );
}

=head2 can_be_put_on_hold() : Bool

Returns true if the shipment can be put on hold.

=cut

sub can_be_put_on_hold {
    my $self = shift;
    return $self->is_on_finance_hold || $self->is_processing || $self->is_held;
}

=head2 can_be_put_on_finance_hold() : Bool

Returns true if the shipment can be put on finance hold.

=cut

sub can_be_put_on_finance_hold {
    return shift->is_processing;
}

=head2 put_on_hold( \%params )

Place this shipment on hold.

=cut

sub put_on_hold {
    my ($self,$params) = @_;

    return set_shipment_on_hold(
        $self->result_source->schema,
        $self->id,
        $params
    );
}

=head2 set_on_hold

An alias for C<< $self->set_on_hold >>.

=cut

sub set_on_hold { goto &put_on_hold };

=head2 can_be_released_from_hold

Returns true if this shipment can be released from hold.

=cut

sub can_be_released_from_hold {
    return shift->is_on_hold;
}

=head2 release_from_hold(:operator_id) :

Release this shipment from hold.

=cut

sub release_from_hold {
    my ($self, $operator_id) = validated_list(\@_,
        operator_id => { isa => 'Int' }
    );

    die 'Shipment not correct status to be released: ' . $self->shipment_status->status
        unless $self->can_be_released_from_hold;

    return $self->update_status($SHIPMENT_STATUS__PROCESSING, $operator_id);
}

=head2 hold_if_invalid(\%params)

Place this shipment on hold if it's invalid (i.e. it has an invalid address).

=cut

sub hold_if_invalid {
    my ($self,$params) = @_;

    return unless $self->should_hold_if_invalid_address;

    return if $self->has_validated_address;

    $self->put_on_hold({
        status_id => $SHIPMENT_STATUS__HOLD,
        norelease => 1,
        reason => $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
        comment => 'automatic hold due to invalid address',
        %$params,
    });
}

=head2 should_hold_if_invalid_address() : Bool

Read the config to determine if in this instance of XT shipments that fail
address validation due to an invalid address should be held.

=cut

sub should_hold_if_invalid_address {
    return XTracker::Config::Local::config_var(qw/Warehouse hold_if_invalid_address/);
}

=head2 hold_for_prepaid_reason(\%params)

Put this shipment on HOLD for PREPAID reason

=cut

sub hold_for_prepaid_reason {
    my ($self,$params) = @_;

    $self->put_on_hold({
        status_id   => $SHIPMENT_STATUS__HOLD,
        norelease   => 1,
        reason      => $SHIPMENT_HOLD_REASON__PREPAID_ORDER,
        %$params,
    });
}

=head2 is_pigeonhole_only

Returns true if all the items are either in a pigeon hole or in no container
but marked missing from a pigeon hole.

=cut

sub is_pigeonhole_only {
    my ($self) = @_;

    return unless $self->shipment_items->count();

    # slightly painful way of checking, we need to return true
    # if all the items are
    # - in a pigeon hole
    # OR
    # - in no container, but marked missing from a pigeon hole
    my $pigeonhole_only = 1;
    foreach my $shipment_item ($self->shipment_items->all) {
        if ($shipment_item->container_id) {
            unless ($shipment_item->container_id->is_type('pigeon_hole')) {
                $pigeonhole_only = undef;
                last;
            }
        } elsif ($shipment_item->old_container_id ) {
            unless ($shipment_item->old_container_id->is_type('pigeon_hole')) {
                $pigeonhole_only = undef;
                last;
            }
        } else {
            # not in a container at all
            # this happens when the item has been quarantined
            # we'll just assume it wasn't in a pigeon hole before, anything
            # that uses this method will have to be aware that we can't track
            # ph items once they've been quarantined
            $pigeonhole_only = undef;
            last;
        }
    }

    return $pigeonhole_only;
}

=head2 has_pigeonhole_items

Returns a true value if any of the items are in or are missing from a
pigeonhole.

=cut

sub has_pigeonhole_items {
    my ($self) = @_;

    foreach my $shipment_item ($self->shipment_items->all) {
        if ($shipment_item->container_id &&
            $shipment_item->container_id->is_type('pigeon_hole')
        ) {
            return 1;
        }
        if ($shipment_item->old_container_id &&
            $shipment_item->old_container_id->is_type('pigeon_hole')
        ) {
            return 1;
        }
    }

    return;
}

=head2 change_status_to( $status_id, $operator_id, [$no_log] )

Change the order status to what is being passed and log it. Note that this does not
check the workflow of the states

=cut

sub change_status_to {
    my($self,$status_id,$operator_id,$no_log) = @_;

    $self->result_source->schema->txn_do(sub{
        $self->update({ shipment_status_id => $status_id });
        return if $no_log;
        $self->create_related('shipment_status_logs', {
            shipment_status_id => $status_id, operator_id => $operator_id,
        });
    });
}

=head2 set_status_processing( $operator_id, [$no_log] )

Set the order status to B<Processing> and log it

=cut

sub set_status_processing {
    my($self,$operator_id,$no_log) = @_;
    die "Expecting operator_id to log action against" if (!defined $operator_id);

    $self->change_status_to( $SHIPMENT_STATUS__PROCESSING, $operator_id, $no_log );
}

=head2 set_status_finance_hold( $operator_id, [$no_log] )

Set the order status to 'Finance Hold' and log it

=cut

sub set_status_finance_hold {
    my($self,$operator_id,$no_log) = @_;
    die "Expecting operator_id to log action against" if (!defined $operator_id);

    $self->change_status_to( $SHIPMENT_STATUS__FINANCE_HOLD, $operator_id, $no_log );
}

=head2 set_status_hold( $operator_id, $reason_id )

Set the order status to 'Hold' and add a shipment_reason_hold.

This based on XTracker::Database::Shipment->create_shipment_hold but not
fully implemented

=cut

sub set_status_hold {
    my($self,$operator_id,$reason_id,$comment,$no_log) = @_;

    croak "Expecting operator_id so we know who to blame"
        if (!defined $operator_id);
    croak "Expecting reason_id so we know why its on hold"
        if (!defined $reason_id);

    $self->result_source->schema->txn_do(sub {
        $self->change_status_to( $SHIPMENT_STATUS__HOLD, $operator_id, $no_log );

        # Create a shipment_hold record, and remove any existing ones for the
        # same reason. This is pretty clumsy, but we currently expect one hold
        # reason only when we're on hold.
        $self->clear_shipment_hold_records_for_reasons($reason_id);
        $self->create_related('shipment_holds',{
            operator_id => $operator_id,
            shipment_hold_reason_id => $reason_id,
            comment => $comment,
            hold_date => \'NOW()',
        });

        my $latest_status_change_log;
        if (!$no_log) {
            # If we have logged this status change, link hold log explicitly to the
            # status-change-log, so we know whay this change was made
            $latest_status_change_log = $self->search_related('shipment_status_logs', {
                shipment_status_id  => $SHIPMENT_STATUS__HOLD,
                operator_id         => $operator_id,
            }, {
                order_by=> { -desc => 'date' },
                rows    => 1,
            })->first();
        }

        $self->create_related( 'shipment_hold_logs', {
            operator_id => $operator_id,
            shipment_hold_reason_id => $reason_id,
            comment => $comment,
            date    => \'NOW()',
            ( $latest_status_change_log
                ? ( shipment_status_log_id => $latest_status_change_log->id() )
                : ()
            ),
        } );

    });

    $self->send_hold_update();
}

=head2 has_same_address_as_billing_address

Compares the shipping address associated with this shipment and compares it to
the billing address (on public.orders)

=cut

sub has_same_address_as_billing_address {
    my($self) = @_;

    my $match = 0;

    if($self->shipment_address_id
         == $self->orders->first->invoice_address_id){
        # Addresses are the same record
        $match = 1;
    }
    elsif($self->shipment_address
               ->is_equivalent_to($self->orders->first->invoice_address)){
        # Addresses have field equivalence
        $match = 1
    }
    else{
        # No match
    }

    return $match;
}

=head2 count_address_in_uncancelled_for_customer

Count the number of times the shipping address has been used on other shipments
that have not been cancelled for the customer or given customer list

=cut

sub count_address_in_uncancelled_for_customer {
    my $self = shift;
    my $args = shift || {};

    my %include_customer = ();

    if ( exists $args->{'customer_list'} ) {
      %include_customer = (
            'orders.customer_id' => {
                '-in'  => $args->{'customer_list'},
            },
        );
    } else {
        %include_customer = (
            'orders.customer_id' => $self->order->customer_id,
        );

    }

    my $schema = $self->result_source->schema;
    my $set = $schema->resultset('Public::Shipment')->search(
        {
            shipment_address_id => $self->shipment_address_id,
            shipment_status_id => { '!=' => $SHIPMENT_STATUS__CANCELLED },
            %include_customer,
        },
        {
            'join' => { 'link_orders__shipments' => 'orders' },
        },
    );

    return $set->count;
}

=head2 count_address_in_uncancelled

Count the number of times the shipping address has been used on other shipments
that have not been cancelled

=cut

sub count_address_in_uncancelled {
    my($self) = @_;

    my $schema = $self->result_source->schema;
    my $set = $schema->resultset('Public::Shipment')->search({
        shipment_address_id => $self->shipment_address_id,
        shipment_status_id => { '!=' => $SHIPMENT_STATUS__CANCELLED },
    });

    return $set->count;
}

=head2 packing_summary() : $packing_summary_obj

Return a summary of the Packing status for the Shipment and its
items. This is a XT::Data::Packing::Summary object, which stringifies
into a user-facing message string.

=cut

sub packing_summary {
    my $self = shift;
    return XT::Data::Packing::Summary->new({ shipment_row => $self })->as_string;
}

=head2 shipment_type_for_packing

Replicating the logic in L<XTracker::Order::Printing::PickingList> that
decides which shipping type to display on picking sheet, in a way that can be
used on the packing screen.

=cut

sub shipment_type_for_packing {
    my ($self) = @_;

    my $type;

    # we don't care about this enough to want to die if something goes wrong
    eval {
        ### highlight Domestic/Express shipments (Guernsey & Jersey classed as UK for DC1 only)
        if ($self->is_domestic ||
                ($self->get_channel->is_on_dc( $DISTRIB_CENTRE__DC1 ) &&
                    ($self->shipment_address->country eq 'Jersey' ||
                    $self->shipment_address->country eq 'Guernsey')
                )
           ) {

            if ($self->in_premier_area()) {
                ### shipment within Premier zone but not Premier
                if ($self->get_channel->is_on_dc($DISTRIB_CENTRE__DC2)) {
                    # NY Metro for DC2
                    $type = "NY Metro";
                } else {
                    # default to Express for the others
                    $type = "Express";
                }
            } else {
                # standard domestic shipment
                if ($self->get_channel->is_on_dc($DISTRIB_CENTRE__DC2)) {
                    # DC2 need further breakdown of domestic shipments between Ground and Express
                    if ($self->charge_class eq 'Ground') {
                        # Ground delivery
                        $type = "United States Ground";
                    } else {
                        # Air or 'Express' delivery
                        $type = "United States Express";
                    }
                } else {
                    # everyone else just uses DC country name for domestic
                    $type = "Domestic";
                }
            }
        }

        if ( $self->get_channel->is_on_dc($DISTRIB_CENTRE__DC1) && $self->is_international ) {
            my $sub_region = $self->result_source->schema->resultset('Public::SubRegion')->search({
                'countries.country' => $self->shipment_address->country,
            },
            {
                join => 'countries',
            })->first;

            if ($sub_region && ($sub_region->sub_region eq 'EU Member States')) {
                ### highlight EU shipments sent from DC1
                $type = "EU";
            }
        }

        if ($self->get_channel->is_on_dc($DISTRIB_CENTRE__DC2) &&
                $self->shipment_address->country eq 'Canada') {
            ### highlight Canadian shipments sent from DC2
            $type = "Canada Express";
        }
    };

    if ( $@ ) {
        xt_logger->warn($@);
    }

    return $type;
}

=head2 is_voucher_only : Boolean

Whether this Shipment contains only Shipment Items which are Vouchers.

=cut

sub is_voucher_only {
    my $self = shift;
    my $non_voucher_count = grep { ! $_->is_voucher } $self->shipment_items->all;
    return ! $non_voucher_count;
}

=head2 hs_codes

Returns an array ref listing the HS codes for the items in this shipment. If multiple
items have the same HS code, then the code will appear multiple times in the list.

=cut

sub hs_codes {
    my ($self) = @_;

    my @codes = $self->non_cancelled_items
        ->related_resultset('variant')
        ->related_resultset('product')
        ->related_resultset('hs_code')
        ->get_column('hs_code')
        ->all;
    return \@codes;
}

=head2 is_ddu_hold

Returns a boolean indicating whether the shipment is on DDU hold.

=cut

sub is_on_ddu_hold {
    my ( $self ) = @_;

    return $self->shipment_status_id == $SHIPMENT_STATUS__DDU_HOLD;
}

=head2 is_signature_required

    $boolean    = $shipment->is_signature_required;

This returns either TRUE or FALSE depending on the state of the field 'signature_required'. Also reason for method
is historical data is NULL and so a NULL also implies TRUE that Signature WAS Required.

=cut

sub is_signature_required {
    my $self    = shift;

    return (
            !defined $self->signature_required
                || $self->signature_required
            ? 1     # TRUE  - Signature IS Required
            : 0     # FALSE - Signature is NOT Required
        );
}

=head2 update_signature_required

    $boolean    = $shipment->update_signature_required( $boolean, $operator_id );

This will update the 'signature_required' flag and log the change in the 'log_shipment_signature_required'
table. It will only do this if the new value is different from the old one.

Returna 1 or 0 depending on whether anything was actually Updated.

=cut

sub update_signature_required {
    my ( $self, $new_state, $operator_id )  = @_;

    if ( !defined $new_state
        || $new_state !~ /^[01]$/ ) {
        croak "'update_signature_required' passed an incorrect 'new_state' argument should be 1 or 0 not: "
              . ( defined $new_state ? $new_state : 'undef' );
    }
    if ( !defined $operator_id ) {
        croak "'update_signature_required' passed an undefined 'operator_id'";
    }

    # if there is no change then just return and do nothing
    return 0    if ( defined $self->signature_required && $self->signature_required == $new_state );

    $self->update( { signature_required => $new_state } );
    $self->create_related( 'log_shipment_signature_requireds', {
                                            new_state   => $new_state,
                                            operator_id => $operator_id,
                                    } );

    return 1;
}

=head2 can_edit_signature_flag

    $boolean = $shipment->can_edit_signature_flag();

This returns TRUE or FALSE depending on whether this Shipment can have it 'signature_required' flag edited or not.

=cut

sub can_edit_signature_flag {
    my $self    = shift;

    my $retval  = 0;

    if ( number_in_list( $self->shipment_status_id,
                            $SHIPMENT_STATUS__FINANCE_HOLD,
                            $SHIPMENT_STATUS__PROCESSING,
                            $SHIPMENT_STATUS__HOLD,
                            $SHIPMENT_STATUS__RETURN_HOLD,
                            $SHIPMENT_STATUS__EXCHANGE_HOLD,
                            $SHIPMENT_STATUS__DDU_HOLD,
                       )
        && !$self->is_shipment_packed ) {
        # then it's ok to be edited
        $retval = 1;
    }

    return $retval;
}

=head2 invoice_address

Return the invoice address for this shipment.

=cut

sub invoice_address {
    my $self = shift;

    return $self->order->invoice_address;
}

=head2 branded_salutation

Return the branded salutation for this shipment.

=cut

sub branded_salutation {
    my $self = shift;

    my $channel  = $self->get_channel;
    my $customer = $self->order && $self->order->customer;

    return $channel->business->branded_salutation( get_order_address_customer_name( $self->shipment_address, $customer ));
}

=head2 update_nominated_day($nominated_dispatch_date, $nominated_delivery_date) : 1

Update the Nominated Day (including SLA) related columns given the new
DateTime $nominated_dispatch_date and $nominated_delivery_date.

=cut

sub update_nominated_day {
    my ($self, $nominated_delivery_date, $nominated_dispatch_date) = @_;

    my $nominated_day = $self->get_nominated_day({
        nominated_delivery_date => $nominated_delivery_date,
        nominated_dispatch_date => $nominated_dispatch_date,
    });

    my $schema = $self->result_source->schema;
    $schema->txn_do(
        sub {
            $self->update({
                nominated_delivery_date  => $nominated_delivery_date,
                nominated_dispatch_time  => $nominated_day->dispatch_time,
                nominated_earliest_selection_time
                    => $nominated_day->earliest_selection_time,
            });
            $self->discard_changes; # Reload the values back into the object

            $self->apply_SLAs();
        },
    );

    return 1;
}

sub get_nominated_day {
    my ($self, $args) = @_;

    my $nominated_day = XT::Data::NominatedDay::Order->new({
        schema           => $self->result_source->schema,
        delivery_date    => $args->{nominated_delivery_date},
        dispatch_date    => $args->{nominated_dispatch_date},
        shipping_charge  => $self->shipping_charge_table,
        shipping_account => $self->shipping_account,
        timezone         => $self->order->channel->timezone,
    });

    return $nominated_day;
}

=head2 reset_nominated_day() : 0|1

If the current Shipping Charge indicates that this isn't a Nominated
Day, clear out all Nominated Day information and if needed, re-apply
the SLA calculation.

Return 1 if the Shipment has a Nominated Day, else 0.

=cut

sub reset_nominated_day {
    my ($self, $nominated_delivery_date, $nominated_dispatch_date) = @_;

    if( $self->shipping_charge_table->is_nominated_day ) {
        return 1;
    }
    # it isn't a nominated day...

    if( ! $self->nominated_delivery_date ) {
        return 0;
    }
    # ...but it has Nominated Day information that needs clearing out

    $self->result_source->schema->txn_do(
        sub {
            $self->update({
                nominated_delivery_date           => undef,
                nominated_dispatch_time           => undef,
                nominated_earliest_selection_time => undef,
            });
            $self->discard_changes; # Reload the values back into the object

            $self->apply_SLAs();
        },
    );

    return 0;
}

sub has_routing_exports {
    my($self) = @_;
    return 1 if ($self->link_routing_export__shipments
        && $self->link_routing_export__shipments->count > 0);
    return 0;
}

sub has_manifests {
    my($self) = @_;
    return 1 if ($self->link_manifest__shipments
        && $self->link_manifest__shipments->count > 0);
    return 0;
}

=head2 is_ddu_pending

This method returns a true value if the shipment has a 'DDU Pending' flag.
It is a DBIC replacement for
L<XTracker::Database::Shipment::get_shipment_ddu_status>.

=cut

sub is_ddu_pending { $_[0]->_has_flag_id($FLAG__DDU_PENDING); }

=head2 is_on_preorder

This method returns a true value if the shipment has a 'Pre-Order' flag.
It is a DBIC replacement for
L<XTracker::Database::Shipment::get_shipment_preorder_status>.

=cut

sub is_on_preorder { $_[0]->_has_flag_id($FLAG__PRE_DASH_ORDER); }

sub _has_flag_id {
    my ( $self, $flag_id ) = @_;
    return 1
        && $self->search_related('shipment_flags', { flag_id => $flag_id })
                ->count;
}

=head2 is_processing

Returns a true value if the shipment has a status of 'Processing'.

=cut

sub is_processing { $_[0]->shipment_status_id == $SHIPMENT_STATUS__PROCESSING; }

=head2 is_on_finance_hold

Returns a true value if the shipment has a status of 'Finance Hold'.

=cut

sub is_on_finance_hold {
    $_[0]->shipment_status_id == $SHIPMENT_STATUS__FINANCE_HOLD;
}

=head2 log_correspondence

    $shipment->log_correspondence( $CORRESPONDENCE_TEMPLATES__??, $operator_id );

This will log a Correspondence Template Id that was sent for a Shipment along with the Operator Id of who sent the correspondence.

It will create a 'shipment_email_log' record. This can replace in time the following function: 'XTracker::EmailFunctions::log_shipment_email'.

=cut

sub log_correspondence {
    my ( $self, $template_id, $operator_id )    = @_;

    return $self->create_related( 'shipment_email_logs', {
                                            correspondence_templates_id => $template_id,
                                            operator_id                 => $operator_id,
                                            date                        => \'current_timestamp',
                                    } );
}

=head2 get_return_correspondence_logs

    $result_set = $shipment->get_return_correspondence_logs();

This will get all of the Return Email Logs for all of the Shipment's Returns.

=cut

sub get_return_correspondence_logs {
    my $self    = shift;

    return $self->returns
                    ->search_related('return_email_logs');
}

=head2 shipping_charge_as_money : $str

Return the shipping_charge value with two decimals.

=cut

sub shipping_charge_as_money {
    my $self = shift;
    return sprintf("%.2f", $self->shipping_charge);
}

=head2 premier_mobile_number_for_SMS

    $string = $shipment->premier_mobile_number_for_SMS;

Returns a Mobile Number for a Premier Shipment (regardless of whether the Shipment is actually Premier). This method
will return back a Phone Number with a Country Code prefix on it based on the following rules:

    * If the Invoice and shipping country = same AND telephone number = same,
      then use shipping country and shipping telephone number.
    * If the Invoice and shipping country = same AND telephone number = different,
      then use shipping country and shipping telephone number.
    * If the Invoice and shipping country = different AND telephone number = same,
      then use invoice country and shipping telephone number.
    * If the Invoice and shipping country = different AND telephone number = different,
      then use invoice country and invoice telephone number.

The Telephone Number used in the above rules will be derivied by using the following rule:

    Use the 'mobile_telephone' field, ELSE if that
    is not populated then use the 'telephone' field.

    If the Shipment or Invoice Number is Empty, but the other
    one isn't then use that number regardless of the above rules
    but prefix it with the appropriate country code.

All spaces will be removed from the number along with anything that isn't a digit except a leading '+'.

The Mobile Number will be checked with the 'known_mobile_number_for_country' to see if it's a Mobile, if this returns
FALSE then an Empty String will be returned.


Remember a Premier Shipping Address will always be local to the DC and so can't always be relied upon to be the country of the Mobile number.

=cut

sub premier_mobile_number_for_SMS {
    my $self    = shift;

    my $mobile  = "";

    return $mobile          if ( !$self->order );   # empty string if Shipment not for an Order

    my $shp_number  = $self->get_phone_number( { start_with => 'mobile' } );
    my $inv_number  = $self->order->get_phone_number( { start_with => 'mobile' } );
    return $mobile          if ( !$inv_number && !$shp_number );    # return an empty string if there are no numbers

    # if the Shipment Number has a leading '+' then assume country is all there and just use that
    return $shp_number      if ( $shp_number =~ m/^\+/ && known_mobile_number_for_country( $shp_number ) );

    my $shp_country = $self->shipment_address->country_table;
    my $inv_country = $self->order->invoice_address->country_table;

    my $country;

    if ( $shp_country->id == $inv_country->id ) {
        $country    = $shp_country;
        if ( $shp_number eq $inv_number ) {
            $mobile     = $shp_number;
        }
        else {
            $mobile     = $shp_number || $inv_number;
        }
    }
    else {
        $country    = $inv_country;
        if ( $shp_number eq $inv_number ) {
            $mobile     = $shp_number;
        }
        else {
            $mobile     = $inv_number || $shp_number;
        }
    }

    # now get the Country Prefix
    $mobile = prefix_country_code_to_phone( $mobile, $country );

    # only return the number if we think it's a Mobile Number, else empty string
    return ( known_mobile_number_for_country( $mobile ) ? $mobile : "" );
}

=head2 set_carrier_automated( FALSE|TRUE )

This sets the 'real_time_carrier_booking' (rtcb) field on the 'shipment' table
to either TRUE or FALSE. If the setting is FALSE then it will reset the
Outbound & Return Airway Bills on the Shipment record to 'none' so that the
Shipment will be picked up in a Manifest Request which amongst other things
looks for Shipment which don't have those fields completed.

=head2 NOTE

Ported from L<XTracker::Database::Shipment::set_carrier_automated>.

=cut

sub set_carrier_automated {
    my ( $self, $state ) = @_;

    croak 'Argument has to be 0 or 1' unless $state =~ m{^(?:0|1)$};

    my %update_param = ( real_time_carrier_booking => $state );

    # Clear extra fields if setting rtcb to false
    %update_param = (
        outward_airway_bill => 'none',
        return_airway_bill  => 'none',
        av_quality_rating   => q{},
        %update_param,
    ) unless $state;
    return $self->update(\%update_param);
}

=head2 assign_boxes('Outer Box Name','Inner Box Name')

Associate outer and inner boxes to the shipment. The name of the box must exist
for the channel

=cut

sub assign_boxes {
    my($self,$outer_box_name,$inner_box_name) = @_;
    my $schema = $self->result_source->schema;
    my $channel_id = $self->get_channel->id;
    my $box_id = $schema->resultset('Public::Box')
        ->search({
            box => $outer_box_name,
            channel_id => $channel_id
        })->first->id;

    my $in_box_id   = $schema->resultset('Public::InnerBox')
        ->search({
            inner_box => $inner_box_name,
            channel_id => $channel_id
        })->first->id;

    return $self->create_related(
        'shipment_boxes', {
            box_id => $box_id,
            inner_box_id => $in_box_id,
        });
}

=head2 is_saturday_nominated_delivery_date

Checks if the this shipment has a Nominated Delivery Date which is on
a B<Saturday>.

=cut

sub is_saturday_nominated_delivery_date {
    my($self) = @_;

    return 0 if (!defined $self->nominated_delivery_date);

    # 1-7 (Monday is 1) - from DateTime docs
    return 1 if ($self->nominated_delivery_date->day_of_week == 6);
    return 0;
}

=head2 get_gift_messages

Returns an array of gift message objects for the shipment

=cut

sub get_gift_messages {
    my $self = shift;

    my $valid_msg_ptr = sub {
        my $msg = shift;
        return if (!defined($msg));
        return if ($msg eq '');
        return if ($msg eq 'Your message goes here');
        return 1;
    };

    my @all_gift_messages;

    if ($valid_msg_ptr->($self->gift_message)) { # valid gift message on shipment object
        push(@all_gift_messages, XTracker::Order::Printing::GiftMessage->new({
            shipment => $self
        }));
    }

    my $sh_items_rs = $self->shipment_items->search({
        -and => [
            { gift_message => { '!=' => undef } },
            { gift_message => { '!=' => '' } }
        ]
    });

    while (my $sh_items_rs = $sh_items_rs->next) {
        next if $sh_items_rs->is_virtual_voucher;
        next if (!$valid_msg_ptr->($sh_items_rs->gift_message));

        push(@all_gift_messages, XTracker::Order::Printing::GiftMessage->new({
            shipment => $self,
            shipment_item => $sh_items_rs
        }));

    }

    return \@all_gift_messages;
}

=head2 has_gift_messages

Returns a boolean denoting on if there are any gift messages

=cut

sub has_gift_messages {
    my $self = shift;

    my $gms = $self->get_gift_messages();
    return (scalar(@$gms) > 0);

}

=head2 pre_order_create_cancellation_card_refund

    $renumeration_object    = $shipment->pre_order_create_cancellation_card_refund( [ $shipment_ids_cancelled ], $operator_id );

This will create a Cancellation Card Refund for a Standard Class Shipment only for a Pre-Order Order. This could be used
for normal Order's should the need arise but I am Restricting it now to be used for Orders linked to a Pre-Order
and for Standard Class Shipments only.

=cut

sub pre_order_create_cancellation_card_refund {
    my ( $self, $item_ids, $operator_id )   = @_;

    my $order   = $self->order;
    return      if ( !$order );                         # NON-Order Shipments can't do this
    return      if ( !$self->is_standard_class );       # Only for Standard Class Shipments
    return      if ( !$order->was_a_card_used );        # Only if a Card was used and has a
                                                        # remaining value left on it to refund

    if ( !$order->has_preorder ) {
        croak "Shipment's Order is NOT linked to a Pre-Order, Order Id: " . $order->id;
    }

    croak "No Array of Cancelled Shipment Ids passed in to '" . __PACKAGE__ . "'"
                                    if ( !$item_ids || ref( $item_ids ) ne 'ARRAY' );
    croak "No Operator Id passed in to '" . __PACKAGE__ . "'"
                                    if ( !$operator_id );

    # get the Card Debit Tender used
    my $card_tender = $order->card_debit_tender;

    my @items_to_cancel = $self->shipment_items
                                    ->search( {
                                                id                      => { 'in' => $item_ids },
                                                shipment_item_status_id => { 'in' => [
                                                                                        $SHIPMENT_ITEM_STATUS__CANCELLED,
                                                                                        $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                                                                                    ],
                                                                            },
                                            }, { order_by => 'id' } )->all;

    my @items_to_refund;
    my $total_to_refund = 0.000;

    # loop round getting the value to refund for each item;
    foreach my $item ( @items_to_cancel ) {
        # get previously refunded amounts for the item
        my ( $takeoff_price, $takeoff_tax, $takeoff_duty )  = $item->refund_invoice_total();
        my $to_refund   = {
                            item    => $item,
                            price   => $item->unit_price - $takeoff_price,
                            tax     => $item->tax - $takeoff_tax,
                            duty    => $item->duty - $takeoff_duty,
                        };
        $total_to_refund    += ( $to_refund->{price} + $to_refund->{tax} + $to_refund->{duty} );
        push @items_to_refund, $to_refund;
    }

    if ( $total_to_refund <= 0.0001 ) {
        # nothing to refund so don't
        return;
    }
    if ( $total_to_refund > ( $card_tender->remaining_value + 1 ) ) {
        # run out of Tenders to refund with.
        # '+1' to allow for rounding errors
        return;
    }

    my $dbh = $self->result_source->schema->storage->dbh;

    # now create a Refund Invoice for Cancellation
    my $invoice_id  = create_invoice(
                            $dbh,
                            $self->id,                          # Shipment Id
                            '',                                 # Invoice Number
                            $RENUMERATION_TYPE__CARD_REFUND,
                            $RENUMERATION_CLASS__CANCELLATION,
                            $RENUMERATION_STATUS__AWAITING_ACTION,
                            0.00,                               # Shipping Refund Always ZERO for Pre-Order
                            0.00,                               # Misc Refund Amount
                            0,                                  # Alternative Customer Id
                            0.00,                               # Gift Credit Amount
                            0.00,                               # Store Credit Amount
                            $order->currency_id,
                            0.00,                               # Gift Voucher Amount
                        );
    # now create the Invoice Items
    foreach my $item ( @items_to_refund ) {
        create_invoice_item(
                            $dbh,
                            $invoice_id,
                            $item->{item}->id,
                            $item->{price},
                            $item->{tax},
                            $item->{duty},
                        );
    }
    log_invoice_status( $dbh, $invoice_id, $RENUMERATION_STATUS__AWAITING_ACTION, $operator_id );

    my $invoice = $self->discard_changes
                        ->renumerations
                            ->find( $invoice_id );

    # create the renumeration tenders for the invoice
    $invoice->create_related( 'renumeration_tenders', {
                                            tender_id   => $card_tender->id,
                                            value       => $total_to_refund,
                                        } );

    return $invoice;
}

=head2 has_hazmat_items

Returns true if shipment has hazmat products in it

=cut

sub has_hazmat_items {
    my $self = shift;

    return 1 if $self->non_cancelled_items
        ->related_resultset('variant')
        ->related_resultset('product')
        ->related_resultset('link_product__ship_restrictions')
        ->search({ ship_restriction_id => $SHIP_RESTRICTION__HAZMAT })
        ->count > 0;

    return 0;
}


=head2 has_aerosol_items

Returns true if shipment has aerosol products in it

=cut

sub has_aerosol_items {
    my $self = shift;

    return 1 if $self->non_cancelled_items
        ->related_resultset('variant')
        ->related_resultset('product')
        ->related_resultset('link_product__ship_restrictions')
        ->search({ ship_restriction_id => $SHIP_RESTRICTION__HZMT_AERO })
        ->count > 0;

    return 0;
}


=head2 has_hazmat_lq_items

Returns true if shipment has Hazmat LQ products in it

=cut

sub has_hazmat_lq_items {
    my $self = shift;

    return 1 if $self->non_cancelled_items
        ->related_resultset('variant')
        ->related_resultset('product')
        ->related_resultset('link_product__ship_restrictions')
        ->search({ ship_restriction_id => $SHIP_RESTRICTION__HZMT_LQ })
        ->count > 0;

    return 0;
}


=head2 count_items_of_product_types

    $integer = $self->count_items_of_product_types( [
        # array ref of Product Types
        'Bracelet',
        'Shoulder Bags',
        ...
    ] );

Returns the number of Non-Cancelled Items for the Shipment
whose Product Type is one of the list of Types passed in.

=cut

sub count_items_of_product_types {
    my ( $self, $product_types ) = @_;

    my @products = $self->non_cancelled_items
                            ->search_related('variant')
                                ->search_related('product')
                                    ->all;

    my $counter = 0;
    foreach my $product ( @products ) {
        $counter++      if ( $product->has_product_type_of( $product_types ) );
    }

    return $counter;
}

=head2 has_items_of_product_types

    $boolean = $self->has_items_of_product_types( $product_type_array_ref );

Returns TRUE or FALSE depending on whether any of the Non-Cancelled Items for
the Shipment are for one of the passed in Product Types.

See 'count_items_of_product_types' of what the $product_type_array_ref should be.

=cut

sub has_items_of_product_types {
    my ( $self, $product_types ) = @_;

    return (
        $self->count_items_of_product_types( $product_types )
        ? 1
        : 0
    );
}

=head2 has_only_items_of_product_types

    $boolean = $self->has_only_items_of_product_types( $product_type_array_ref );

Returns TRUE or FALSE depending on whether all of the Non-Cancelled Items for
the Shipment are for one of the passed in Product Types.

See 'count_items_of_product_types' of what the $product_type_array_ref should be.

=cut

sub has_only_items_of_product_types {
    my ( $self, $product_types ) = @_;

    my $all_items_count     = $self->non_cancelled_items->count;
    my $product_types_count = $self->count_items_of_product_types( $product_types );

    return (
        $all_items_count == $product_types_count
        ? 1
        : 0
    );
}

=head2 get_physical_items

Returns an array of shipment items excluding virtual vouchers.

=cut

sub get_physical_items {
    my $self = shift;
    return grep {!$_->is_virtual_voucher} $self->shipment_items;
}

=head2 get_items_by_prl_name

Retrieve the allocated shipment items from this shipment, groups by the ids
of the PRLs they are allocated to.

    return - $allocations : Hashref where key = name of PRL, value = arrayref of shipment items

=cut

sub get_items_by_prl_name {
    my ($self) = @_;

    # Return now unless PRLs are enabled
    return {} unless config_var('PRL', 'rollout_phase');

    # There may be more than one allocation for a PRL
    my %items_by_prl;
    foreach my $allocation ($self->allocations()) {
        my @shipment_items = $allocation->allocation_items->search({
            'status_id' => $ALLOCATION_STATUS__ALLOCATED,
        })->search_related('shipment_item')->all();
        if (@shipment_items) {
            push @{$items_by_prl{$allocation->prl->name()}}, @shipment_items;
        }
    }
    return \%items_by_prl;
}

# Used by selection screen template

sub part_picked {
    my ($self) = @_;
    return 0 if config_var('IWS', 'rollout_phase');

    # This is so we know if the selection is for replacements
    return $self->shipment_items->search({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED })->count();
}

sub nominated_earliest_selection_time_local {
    my ($self) = @_;
    return $self->nominated_earliest_selection_time()->clone()->set_time_zone($self->order->channel->timezone());
}

=head2 get_item_shipping_attributes

    $hash_ref   = $self->get_item_shipping_attributes();

This will return a HashRef of 'Shipping Attributes' for all NON-Cancelled Shipment Items
for the Shipment with the 'Product Id' as the key.

    {
        1232414 => {
            scientific_term     => 'term',
            country_id          => 34,
            cites_restricted    => true,
            is_hazmat           => false,
            ...
            ship_restriction_ids => {
                # Ship Restrictions for a Product (if any)
                RESTRICTION_ID => 1,
                ...
            },
        },
        ...
    }

=cut

sub get_item_shipping_attributes {
    my $self    = shift;

    my %retval;

    my @attribs = $self->shipment_items
                        ->not_cancelled
                        ->not_cancel_pending
                            ->related_resultset('variant')
                                ->related_resultset('product')
                                    ->related_resultset('shipping_attribute')
                                        ->all;

    foreach my $attrib ( @attribs ) {
        my $pid = $attrib->product_id;
        $retval{ $pid }  = {
            $attrib->get_columns,       # turns the record into a HASH
        };
        # get a Hash Ref of any 'ship_restriction' Ids assigned to the Product,
        # use the Id of the restriction so a Constant can be used to check them
        $retval{ $pid }{ship_restriction_ids} = $attrib->product->get_shipping_restrictions_ids_as_hash();
    }

    return \%retval;
}

=head2 is_incorrect_website

    $boolean = is_incorrect_website($shipment);

Return TRUE if shipment country is that of other DC's else return false.

This logic is used to send customer care a notification email if customer places an order
on far DC when a local DC is available which they might not be aware of.

=cut

sub is_incorrect_website {
    my $self    = shift;

    my $shipment_country = $self->shipment_address->country;
    my $incorrect_countries = [];
    $incorrect_countries = config_var('IncorrectWebsiteCountry', 'country');

    if ( $incorrect_countries && ref($incorrect_countries) ne 'ARRAY' ) {
        $incorrect_countries = [$incorrect_countries];
    }

    if ( grep { /^$shipment_country$/ } @{ $incorrect_countries } ) {
      return 1;
    };

    return 0;
}

=head2 has_cage_items

Does the container have any items with the 'Cage' storage type?

=cut

sub has_cage_items {
    my $self = shift;
    return 1 if any { $_->has_cage_items } $self->containers;
}

=head2 can_have_in_the_box_promotions

Returns true if the shipment can have In The Box promotions, false
otherwise. They are currently defined as the shipment class being one
of the following:

 * Standard
 * Re-Shipment
 * Replacement

=cut

sub can_have_in_the_box_promotions {
    my $self = shift;

    return scalar grep { $self->shipment_class_id == $_ } (
        $SHIPMENT_CLASS__STANDARD,
        $SHIPMENT_CLASS__RE_DASH_SHIPMENT,
        $SHIPMENT_CLASS__REPLACEMENT,
    );
}

=head2 get_promotion_types_for_invoice

Returns an ArrarRef containing all the 'Free Gift' and 'In The Box'
promotions required on an invoice.

    my $promotions = $schema
        ->resultset('Public::Shipment')
        ->get_promotion_types_for_invoice;

    foreach my $promotion ( @$promotions ) {

        # ...

    }

=cut

sub get_promotion_types_for_invoice {
    my $self = shift;

    # Make sure we have an order, to ignore things like sample shipments.
    if ( $self->order ) {

        my @promotions;

        if ( $self->is_standard_class ) {

            # All 'Free Gift' Promotions
            push @promotions, scalar $self
                ->order
                ->get_free_gift_promotions;

        }

        if ( $self->can_have_in_the_box_promotions ) {

            # Weighted 'In The Box' Promotions
            push @promotions, scalar $self
                ->order
                ->get_in_the_box_marketing_promotions
                ->get_weighted_promotions;

        }

        return [
            map { $_->promotion_type }
                map { $_->all }
                    @promotions
        ];

    }

    return [];
}

=head2 is_on_hold_for_invalid_address_chars() : Bool

Returns true if the shipment is on hold and has a shipment_hold record with a
shipment_hold_reason_id of Invalid Characters.

=cut

sub is_on_hold_for_invalid_address_chars {
    my $self = shift;

    return undef unless $self->discard_changes->is_held;
    return $self->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__INVALID_CHARACTERS);
}

=head2 is_on_hold_for_reason(reason_id) : Bool

Returns true if the shipment is on hold and has a shipment_hold record with the
specified shipment_hold_reason_id.

=cut

sub is_on_hold_for_reason {
    my $self = shift;
    my ($reason_id) = pos_validated_list(\@_, { isa => 'Int' });

    return undef unless $self->discard_changes->is_on_hold;
    return !!$self->search_related( shipment_holds => {
        shipment_hold_reason_id => $reason_id,
    })->count;
}

=head2 is_on_hold_for_third_party_psp_reason

    $boolean = $self->is_on_hold_for_third_party_psp_reason;

Returns TRUE or FALSE depending on whether the Shipment is on Hold for
a Third Party PSP Payment reason such as:
    Payment Confirmation Pending
    Payment Rejected

=cut

sub is_on_hold_for_third_party_psp_reason {
    my $self = shift;

    my @third_party_psp_reasons = (
        $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
        $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
    );

    foreach my $reason ( @third_party_psp_reasons ) {
        return 1    if ( $self->is_on_hold_for_reason( $reason ) );
    }

    return 0;
}

=head2 clear_invalid_address_shipment_hold_records

Clears all shipment_hold records for this shipment where the hold reason is
Invalid Characters.

=cut

sub clear_invalid_address_shipment_hold_records {
    my $self = shift;

    return $self->clear_shipment_hold_records_for_reasons(
        $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
    );
}

=head2 clear_shipment_hold_records_for_reasons(@reason_ids) : deleted_count

Delete rows from the shipment_hold with the given C<reason_ids> referencing
this shipment.

=cut

sub clear_shipment_hold_records_for_reasons {
    my ( $self, @reason_ids ) = @_;

    return $self->search_related('shipment_holds', {
        shipment_hold_reason_id => \@reason_ids
    })->delete;
}

=head2 validate_address({:operator_id}) : Bool

Validate the shipment's address and return a true value if validation was
successful.

=cut

sub validate_address {
    my ( $self, $args ) = @_;

    my $carrier = $self->nap_carrier($args->{operator_id});
    $carrier->set_address_validator('DHL') unless defined $carrier->carrier;

    my $has_valid_address = $carrier->validate_address;
    $self->update({ has_valid_address => $has_valid_address ? 1 : 0 });

    return $has_valid_address;
}

=head2 nap_carrier($operator_id) : nap_carrier

Return a L<NAP::Carrier> object for this shipment.

=cut

sub nap_carrier {
    my ( $self, $operator_id ) = @_;
    return NAP::Carrier->new({shipment_id => $self->id, operator_id => $operator_id});
}

=head2 get_from_address_data

Returns a hash of data detailing the elements of the 'From' address that is
supplied on airway bills and in the manifest for this shipment.
E.g. The address of the sender (Net-A-Porter, Mr Porter, Jimmy Choo etc...)

(See XTracker::Schema::Result::Public::ShippingAccount::get_from_address_data for
details of return contents)

If this method is called on a shipment with no shipping account an error will be
thrown

=cut
sub get_from_address_data {
    my ($self) = @_;

    my $shipping_account = $self->shipping_account() or
        die 'No shipping account found for shipment with id: ' . $self->id();

    return $shipping_account->get_from_address_data();
}

=head2 can_upgrade_shipment_class

Can we upgrade the shipment class? If so..
.. to what? if AIR, they only if we don't
contain an AEROSOL.

TBH behaviour of a shipment shouldn't be driven
externally but the script is old. However it still
makes more sense to put here than somewhere else.

=cut

sub can_upgrade_shipment_class {
    my $self = shift;

    my $shipping_class = $self->get_shipping_charge_class;
    my $would_go_to_air = $shipping_class->next_upgrade_is_first_to_air;

    return (!($would_go_to_air && $self->has_aerosol_items));
}

=head2 can_be_carrier_automated() : Bool

Returns a boolean determining whether this shipment can be carrier automated.

=cut

sub can_be_carrier_automated {
    my $self = shift;

    # Returning a false value here will prevent virtual voucher only shipments
    # from undergoing the address check
    return undef if $self->is_virtual_voucher_only;

    # we are autoable if the shipment carrier is UPS or DHL
    my $carrier = $self->carrier;
    return undef if not ( $self->carrier_is_dhl || $self->carrier_is_ups );

    # return undef if by AIR and has aerosol items
    return undef if $self->has_aerosol_items;

    return 1;
}

=head2 update_airwaybills($out_airway, $ret_airway)

Accepts the outward and return air waybills and updates them for this shipment.

=cut

sub update_airwaybills {
    my ( $self, $out_airway, $ret_airway ) = @_;
    # Return AWB should be set to 'none' if not returnable
    $ret_airway = ($self->is_returnable && $ret_airway) ? $ret_airway : 'none';
    $out_airway = $out_airway ? $out_airway : 'none';
    $self->update( {
        outward_airway_bill => $out_airway,
        return_airway_bill  => $ret_airway
    } );
    return $self;
}

=head2 clear_airwaybills()

Clears the air waybills for the shipment.

=cut
sub clear_airwaybills {
    my $self = shift;
    $self->update( {
        outward_airway_bill => 'none',
        return_airway_bill  => 'none',
    } );
    return $self;
}

=head2 get_business

Returns the business dbic row assoicated with this shipment

=cut
sub get_business {
    my ($self) = @_;
    return $self->get_channel->business();
}

=head2 get_shipping_class

Returns the shipping class for this shipment

=cut
sub get_shipping_class {
    my ($self) = @_;
    return $self->shipping_account->shipping_class();
}

=head2 get_shipping_charge_class

Returns the shipping-charge class for this shipment

=cut
sub get_shipping_charge_class {
    my ($self) = @_;
    if ( defined $self->shipping_charge_id && $self->shipping_charge_id > 0 ) {
        return $self->shipping_charge_table->shipping_charge_class();
    }
    return undef;
}

=head2 get_shipment_returnable_status

Returns the shipment returnable status for a given shipment_id.

This applies to all DCs for the channels NAP, MRP and OUT.
Any channel that is fulfilment only will return a 'YES' status.

This status is used to decide:

=over 4

=item Whether we produce returns proforma and, if UPS is the carrier, a returns
label;

=item Whether we produce non-returnable warning messages on the shipping input
form (DHL) or pack shipment page (UPS).

=back

=head3 NOTE:

Default return value is $SHIPMENT_ITEM_RETURNABLE_STATE__YES.

Currently, the returned values are:

=over 4

=item $SHIPMENT_ITEM_RETURNABLE_STATE__YES (returns forms printable);

=item $SHIPMENT_ITEM_RETURNABLE_STATE__NO (returns forms NOT printable);

=back

=cut

sub get_shipment_returnable_status {
    my ( $self ) = @_;

    my $channel = $self->get_channel;

    return $SHIPMENT_ITEM_RETURNABLE_STATE__YES if $channel->is_fulfilment_only;

    my %return_statuses = map {$_ => 1} $self->shipment_items->get_column('returnable_state_id')->all;

    if (defined $return_statuses{$SHIPMENT_ITEM_RETURNABLE_STATE__YES}) {
        return $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
    }
    elsif ( defined $return_statuses{$SHIPMENT_ITEM_RETURNABLE_STATE__NO} ||
            defined $return_statuses{$SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY} ) {
        return $SHIPMENT_ITEM_RETURNABLE_STATE__NO;
    }
    return $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
}

=head2 is_returnable

Returns whether the shipment is returnable

=cut

sub is_returnable {
    my ( $self ) = @_;

    return $self->get_shipment_returnable_status() == $SHIPMENT_ITEM_RETURNABLE_STATE__YES ? 1 : 0;
}

=head2 get_currency

Returns the Currency object for this shipment

=cut
sub get_currency {
    my ($self) = @_;
    my $order = $self->order();
    return ($order ? $order->currency() : undef);
}

=head2 get_return_charge

Return the ReturnCharge object for this shipment (if there is one)

=cut
sub get_return_charge {
    my ($self) = @_;
    my $schema = $self->result_source->schema();
    return $schema->resultset('Public::ReturnsCharge')->search({
        channel_id  => $self->get_channel->id(),
        currency_id => $self->get_currency->id(),
        country_id  => $self->shipment_address->country_table->id(),
        carrier_id  => $self->carrier->id(),
    })->first();
}

=head2 display_shipping_input_warning

Returns whether the Shipping Input Form and Pack Shipment page need to display a non-returnable items warning message

=cut

sub display_shipping_input_warning {
    my ( $self ) = @_;
    return ( !$self->is_returnable );
}

=head2 display_no_returns_warning_after_packing

Returns whether a no returns documentation error should be displayed after packing is complete
This is currently only true for DC3

=cut

sub display_no_returns_warning_after_packing {
    my ( $self ) = @_;
    my $channel = $self->get_channel;
    return $self->display_shipping_input_warning && $channel->is_on_dc( $DISTRIB_CENTRE__DC3 );
}

=head2 carrier_is_dhl

Returns whether the carrier for the shipment is DHL

=cut

sub carrier_is_dhl {
    my ( $self ) = @_;
    return $self->carrier->id == $CARRIER__DHL_EXPRESS;
}

=head2 carrier_is_ups

Returns whether the carrier for the shipment is UPS

=cut

sub carrier_is_ups {
    my ( $self ) = @_;
    return $self->carrier->id == $CARRIER__UPS;
}

=head2 has_correct_proforma

Returns whether the Shipment contains the correct proformas

=cut

sub has_correct_proforma {
    my ( $self ) = @_;

    return 1 if $self->is_premier;

    return ( ( $self->outward_airway_bill && $self->outward_airway_bill ne "none" ) &&
             ( !$self->is_returnable || ( $self->return_airway_bill && $self->return_airway_bill ne "none" ) ) );
}

=head2 log_internal_email

Logs that an internal email was sent in respect of the shipment.

Parameters:

subject - The subject line of the email
to      - the recipient of the email
from_file - a hashref detailing which template (in the value to the path key)
from_db  - OR if using a DB template the details of that template

=cut

sub log_internal_email {
    my ( $self, $args ) = @_;

    my $template = defined $args->{from_db} ?
                           $args->{from_db} :
                $args->{from_file}->{path};

    $self->create_related( 'shipment_internal_email_logs', {
        subject     => $args->{subject},
        template    => $template,
        recipient   => $args->{to}
    } );

    return 1;
}

=head2 get_released_from_exchange_hold_datetime

Returns a datetime object for when this shipment was released from exchange hold status

=cut
sub get_released_from_exchange_or_return_hold_datetime {
    my ($self) = @_;

    # If this is not an exchange shipment then it can never have been released from
    # exchange hold
    return undef unless $self->is_exchange();

    # Exchange shipments are created in the status of 'exchange hold' or 'return hold'
    # and therefore there will be no trace of that status in the logs. But that means we
    # know that the first time the status is change to processing is when it was released
    # from hold

    my $log = $self->search_related('shipment_status_logs', {
        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
    }, {
        order_by    => 'date',
        rows        => 1,
    })->first();

    return ($log ? $log->date() : undef);
}

=head2 get_iws_shipment_type

Returns the shipment type as passed to the WMS

=cut
sub get_iws_shipment_type {
    my ($self) = @_;
    return XTracker::Shipment::Classify->new->type($self->shipment_class_id);
}

=head2 get_iws_is_premier

Returns true if the shipment should be considered 'premier' to IWS

=cut
sub get_iws_is_premier {
    my ($self) = @_;
    # sample shipments are modeled as "premier", but IWS
    # should not know this
    return ($self->is_premier() && $self->order() ? 1 : 0);
}

=head2 get_last_release_from_hold_datetime

Returns the last time this shipment was released from 'Manual' hold

(See XTracker::Schema::ResultSet::Public::LastReleasedShipmentHold->get_released_datetime_for_last_shipment_hold()
 for more details)

=cut
sub get_last_release_from_hold_datetime {
    my ($self, $only_include_sla_changeable_reasons,
            $only_include_holds_held_long_enough) = validated_list(\@_,
        only_include_sla_changeable_reasons => { isa => 'Bool', default => 0 },
        only_include_holds_held_long_enough => { isa => 'Bool', default => 0 },
    );

    return $self->result_source->schema->resultset('Public::LastReleasedShipmentHold')
        ->get_released_datetime_for_last_shipment_hold({
        shipment                            => $self,
        only_include_sla_changeable_reasons => $only_include_sla_changeable_reasons,
        only_include_holds_held_long_enough => $only_include_holds_held_long_enough,
    });
}

# Below methods are to fulfil SOS::Shippable Role
sub get_shippable_requested_datetime {
    my ($self) = @_;

    # A shipment might have multiple candidates for its 'requested date'. We'll store
    # them all in this list, and at the end pick the one that is furthest in the future
    my @possible_dates;

    # If the shipment has come off a manual hold that allows recalculation of SLA, we
    # might want to use the date it was released from that hold
    my $last_release_from_hold_datetime = $self->get_last_release_from_hold_datetime({
        only_include_sla_changeable_reasons => 1,
        only_include_holds_held_long_enough => 1,
    });
    push(@possible_dates, $last_release_from_hold_datetime)
        if $last_release_from_hold_datetime;

    if($self->is_exchange()) {

        # Exchange shipments use the date that they were release from exchange/return hold
        push(@possible_dates, $self->get_released_from_exchange_or_return_hold_datetime());

    } elsif($self->is_sample_shipment() || $self->is_reshipment()) {

        # Reshipments use the date that the shipment was created.
        # Sample shipments use the date that the sample was approved
        # (and as the shipment row is created as the sample is approved
        # we can use the shipment creation date for this purpose)
        push(@possible_dates, $self->date());

    } elsif(my $order = $self->order()) {

        # Other (Standard, Staff etc) types of shipment can use the date that the order
        # was placed
        push(@possible_dates, $order->date());

        # Nominated day shipments need to consider their earliest selection time
        my $nominated_earliest_selection_datetime = $self->nominated_earliest_selection_time();
        push(@possible_dates, $nominated_earliest_selection_datetime)
            if $nominated_earliest_selection_datetime;
    }

    # Ho hum, if we don't have any date candidates at this stage then we don't know what
    # to do...
    NAP::XT::Exception::Shipment::OrderRequired->throw({ shipment => $self })
        unless @possible_dates;

    # We have at least one date, pick the one furthest in the future
    @possible_dates = sort { DateTime->compare($a, $b) } @possible_dates;
    return pop @possible_dates;
}

sub get_shippable_carrier {
    my ($self) = @_;
    return $self->carrier();
}

sub get_shippable_channel {
    my ($self) = @_;
    return $self->get_channel();
}

sub get_shippable_country_code {
    my ($self) = @_;
    return $self->shipment_address->country_table->code();
}

sub get_shippable_region_code {
    my ($self) = @_;
    # TODO: Region codes
    # Not using regions yet, but we will. Can't populate this yet because we don't
    # know what regions to check for or what codes we would pass.
    return undef;
}

sub shippable_is_transfer {
    my ($self) = @_;
    return $self->is_transfer_shipment();
}

sub shippable_is_rtv {
    my ($self) = @_;
    return $self->is_rtv_shipment();
}

sub shippable_is_staff {
    my ($self) = @_;
    return $self->is_staff_order();
}

sub shippable_is_premier_daytime {
    my ($self) = @_;
    return 0 unless $self->is_premier();

    # This is a horrible way to check for this, but there isn't a non-horrible
    # practical way to do this really (if you can think of one, answers on a postcard
    # please to the usual address)
    return ($self->shipping_charge_table->description() eq 'Premier Daytime' ? 1 : 0);
}

sub shippable_is_premier_hamptons {
    my ($self) = @_;
    return 0 unless $self->is_premier();

    # This is a horrible way to check for this, but there isn't a non-horrible
    # practical way to do this really (if you can think of one, answers on a postcard
    # please to the usual address)
    return ($self->shipping_charge_table->description() eq 'Premier Evening Hamptons' ? 1 : 0);
}

sub shippable_is_premier_evening {
    my ($self) = @_;
    return 0 unless $self->is_premier();

    # This is a horrible way to check for this, but there isn't a non-horrible
    # practical way to do this really (if you can think of one, answers on a postcard
    # please to the usual address)
    return ($self->shipping_charge_table->description() eq 'Premier Evening' ? 1 : 0);
}

sub shippable_is_premier_all_day {
    my ($self) = @_;
    return 0 unless $self->is_premier();

    # This is a horrible way to check for this, but there isn't a non-horrible
    # practical way to do this really (if you can think of one, answers on a postcard
    # please to the usual address)

    return ((grep { $self->shipping_charge_table->description() eq $_ } (
        # These are the Jimmy Choo Premier shipping-skus. The other channels
        # are covered by Premier Daytime and Evening (above)
        'London Premier',
        'JC NY Premier',
        'FAST TRACK: Premier Anytime'
    )) ? 1 : 0);
}

sub shippable_is_nominated_day {
    my ($self) = @_;

    # This should not include premier shipments
    return 0 if $self->is_premier();

    return 1 if $self->shipping_charge_table->is_nominated_day();

    return 0;
}

sub shippable_is_express {
    my ($self) = @_;
    return $self->shipping_charge_table->is_express();
}

sub shippable_is_eip {
    my ($self) = @_;
    my $customer = $self->order->customer;
    # TON VIPs count as EIPs for shipping purposes
    return $customer->is_an_eip;
}

sub shippable_is_slow {
    my ($self) = @_;
    return $self->shipping_charge_table->is_slow();
}

sub shippable_is_virtual_only {
    my ($self) = @_;
    return $self->is_virtual_voucher_only();
}

=head2 shippable_is_full_sale

Returns true if all items in the shipment are sale items

=cut

sub shippable_is_full_sale {
    my ($self) = @_;
    my @items = $self->active_items;
    my $sale_items = grep { $_->sale_flag && $_->sale_flag->on_sale } @items;

    return ( $sale_items == @items && $sale_items > 0);
}

=head2 shippable_is_mixed_sale

Returns true if some, but not all, items in the shipment are sale items

=cut

sub shippable_is_mixed_sale {
    my ($self) = @_;
    my @items = $self->active_items;
    my $sale_items = grep { $_->sale_flag && $_->sale_flag->on_sale } @items;

    return ( $sale_items > 0 && $sale_items < @items );
}

=head2 is_on_hold_for_pre_order_hold_reason

Returns true if the shipment is on hold and has a shipment hold reasons of
'Prepaid Order' and shipment is for a preorder order.

=cut

sub is_on_hold_for_pre_order_hold_reason {
    my $self = shift;

    return unless $self->is_on_hold;

    return ( $self->order->has_preorder && $self->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__PREPAID_ORDER));


}

=head2 get_shipping_restrictions_for_pre_order

Returns HashRef containing shipping restricted product ids with reasons
for restrictions.

=cut

sub get_shipping_restrictions_for_pre_order {
    my $self = shift;

    my $restrictions = {};
    if( $self->is_on_hold_for_pre_order_hold_reason ) {
        $restrictions = check_shipment_restrictions( $self->result_source->schema, {
            shipment_id => $self->id,
            send_email  => 0
        });
    }

    return $restrictions;
}

=head2 get_ups_services

Returns all shipping services available for this shipment

=cut

sub get_shipping_service_descriptions {
    my ( $self ) = @_;

    my $carrier = NAP::Carrier->new( {

        schema => $self->result_source->schema,
        shipment_id => $self->id,
        operator_id => $APPLICATION_OPERATOR_ID,

    } );

    return $carrier->shipping_service_descriptions();
}


=head2 update_status_based_on_third_party_psp_payment_status

    $self->update_status_based_on_third_party_psp_payment_status;
            or
    $self->update_status_based_on_third_party_psp_payment_status( $operator_id );

If the Order was paid for using a Third Party PSP (PayPal) then this
will put the Shipment on Hold if the Third Party has yet to Accept the
Payment or if they have Rejected the Payment. If they have Accepted the
Payment then this will take the Shipment off Hold and put it to 'Processing'.

It will only change a Standard Class Shipment and it will only change the
Shipment's status if it is 'Processing' or on 'Hold' for a Third Party PSP
reason any other Status or Hold Reason will be left as is.

If NO Operator Id is passed in it will default to the Application Operator.

It can also handle the case where a Payment is NOT for a Third Party but the
Shipment is on Hold for Third Party Reasons. This happens when a new Pre-Auth
is got from our PSP which can only be for a Credit Card and so in this case
the Shipment should be Released from Hold as the reason a new Pre-Auth was
got was probably because the Third Party PSP Rejected the original Payment.

=cut

sub update_status_based_on_third_party_psp_payment_status {
    my ( $self, $operator_id )  = @_;

    # proceed only for Standard Class Shipments
    return      if ( !$self->is_standard_class );

    # proceed only if the Shipment has an Order
    my $order   = $self->order;
    return      if ( !$order );

    # only continue with the rest of this method if
    # Shipment is 'Processing' or is on manual 'Hold'
    return      unless ( $self->is_processing || $self->is_held );

    # proceed only if the Order was paid for using a Third Party
    # or the current Hold Reason is a Third Party PSP Reason
    return      unless ( $order->is_paid_using_third_party_psp
                      || $self->is_on_hold_for_third_party_psp_reason );

    # get the Order's Payment record
    my $payment = $order->payments->first;

    # used to store data about the Third Party Payment
    my $third_party_status;
    my $third_party_label  = '';

    if ( $payment && $payment->method_is_third_party ) {
        # get the Third Party Status for the Payment
        $third_party_status = $payment->get_internal_third_party_status;
        croak "No Third Party Status found for Payment, for Order: '" . $order->order_nr . "'"
                    if ( !$third_party_status );

        # if Accepted & Shipment already Processing then nothing to do
        return      if ( $self->is_processing && $third_party_status->is_accepted );

        # use this in the Hold Comment
        $third_party_label = $order->get_third_party_payment_method->payment_method;
    }

    # use Application Operator if none specified
    $operator_id ||= $APPLICATION_OPERATOR_ID;

    my %hold_args   = (
        operator_id => $operator_id,
        status_id   => $SHIPMENT_STATUS__HOLD,
        norelease   => 1,
    );

    # put the Hold Reasons used by Third Parties here as it's
    # easier to use them in the code because of the long names
    my %third_party_hold_reasons = (
        pending  => $SHIPMENT_HOLD_REASON__CREDIT_HOLD__DASH__SUBJECT_TO_EXTERNAL_PAYMENT_REVIEW,
        rejected => $SHIPMENT_HOLD_REASON__EXTERNAL_PAYMENT_FAILED,
    );

    if ( !$payment || !$payment->method_is_third_party ) {
        # Shipment Must be on Hold for a Third Party Reason to have reached this far,
        # this is for the scenario when a new Pre-Auth has been got from our PSP which
        # will be for a Credit Card and so the Shipment can be taken off Hold
        $self->release_from_hold({ operator_id => $operator_id });
    }
    elsif ( $third_party_status->is_accepted ) {
        # Shipment Must be on Hold to have reached this far
        if ( $self->is_on_hold_for_reason( $third_party_hold_reasons{pending} ) ) {
            $self->release_from_hold({ operator_id => $operator_id });
        }
    }
    elsif ( $third_party_status->is_pending ) {
        # put on Hold unless it already is, in which case leave as is
        $self->put_on_hold( {
            %hold_args,
            reason      => $third_party_hold_reasons{'pending'},
            comment     => "Waiting on Third Party '${third_party_label}' to Accept the Payment",
        } ) unless ( $self->is_held );
    }
    elsif ( $third_party_status->is_rejected ) {
        if ( $self->is_on_hold_for_reason( $third_party_hold_reasons{pending} )
          || $self->is_processing ) {
            $self->put_on_hold( {
                %hold_args,
                reason      => $third_party_hold_reasons{'rejected'},
                comment     => "Third Party '${third_party_label}' has Rejected the Payment",
            } );
        }
    }
    else {
        carp "Unknown Internal Third Party Status: '" . $third_party_status->status . "' " .
              "for Order: '" . $order->order_nr . "'";

        # put on Hold if we don't know the reason unless
        # it already is on Hold, in which case leave as is
        $self->put_on_hold( {
            %hold_args,
            reason      => $third_party_hold_reasons{'pending'},
            comment     => "Unknown Internal Third Party Reason returned from the PSP: '" .$third_party_status->status . "'",
        } ) unless ( $self->is_held );
    }

    return;
}

=head2 validate_address_change_with_psp

    $boolean = $self->validate_address_change_with_psp;

Will call the PSP with the current 'shipment_address' so that the
Payment Provider can be notfied of the change and also validate the
address. This will return TRUE or FALSE depending on what the PSP
returns.

This is used only for Standard Class Shipments and initially only
for PayPal payments.

=cut

sub validate_address_change_with_psp {
    my $self = shift;

    my $retval = 1;

    return $retval      unless ( $self->is_standard_class );

    my $order = $self->order;
    return $retval      unless ( $order && $order->payments->count() );

    my $payment = $self->order->payments->first;
    return $payment->notify_psp_of_address_change_and_validate( $self->shipment_address );
}

=head2 should_notify_psp_when_basket_changes

    $boolean = $self->should_notify_psp_when_basket_changes();

Returns TRUE or FALSE based on whether the Payment Method for the
Order is required to Notify the PSP of any Basket changes such
as Canelling Items.

If the Shipment is NOT linked to an Order (such as a Sample) then
this method will return FALSE.

=cut

sub should_notify_psp_when_basket_changes {
    my $self = shift;

    my $order = $self->order;
    return 0    if ( !$order );

    return $order->payment_method_requires_basket_updates;
}

=head2 notify_psp_of_basket_changes_or_cancel_payment

    undef or $hash_ref = $self->notify_psp_of_basket_changes_or_cancel_payment( {
        context     => 'Amend Pricing',
        operator_id => $operator_id,
    } );

This will check the Balance of the Shipment using 'XT::Domain::Payment::Basket'
which deducts any Store Credit and/or Gift Voucher amounts and if the balance
is greater than zero then it will update the PSP with the current state of the
Basket. But if it is less than or equal to zero then there is no need for the
Payment anymore and so it will be Cancelled and then the 'orders.payment' record
will be Deleted thus making the Order the same as if it had been only paid
with using Store Credit and/or Gift Vouchers originally.

Pass in the 'context' of the update such as when Amending Prices and the
'operator_id' so that these can be used should the Payment be Cancelled.

This method will return 'undef' if nothing happens (e.g. for Sample Shipments),
but if something does happen then it will return a Hash Ref. with keys indicating
what happened:

    Basket Update Sent to PSP:
        {
            psp_sent_basket_update => 1
        }

    Payment Cancelled - see the docs for the return value of the method:
        'XTracker::Schema:Result::Public::Orders->cancel_payment_preauth_and_delete_payment'

=cut

sub notify_psp_of_basket_changes_or_cancel_payment {
    my ( $self, $args ) = @_;

    # not for Sample Shipments
    my $order = $self->order;
    return      if ( !$order );

    # only do this if the Payment Method says we should
    return      if ( !$self->should_notify_psp_when_basket_changes );

    foreach my $param ( qw( context operator_id ) ) {
        croak "No '${param}' was passed in the Arguments for 'notify_psp_of_basket_changes_or_cancel_payment'"
                if ( !$args->{ $param } );
    }

    my $basket  = $self->get_shipment_basket_instance();
    my $balance = $basket->get_balance();

    my $retval;

    if ( $balance > 0 ) {
        # update the PSP with the latest Basket
        $basket->send_basket_to_psp();
        $retval = { psp_sent_basket_update => 1 };
    }
    else {
        # no need for the payment anymore
        my $result = $order->cancel_payment_preauth_and_delete_payment( {
            context     => $args->{context},
            operator_id => $args->{operator_id},
        } );
        $retval = $result       if ( $result );
    }

    return $retval;
}

=head2 notify_psp_of_item_changes

    $self->notify_psp_of_item_changes();
            or
    $self->notify_psp_of_item_changes( [
        { orig_item_id => $original_shipment_item_id, new_item_id => $new_shipment_item_id },
        ...
    ] );

This will notify the PSP of Changes to the Basket if the Payment Method for the Order requires it.
The method uses an instance 'XT::Domain::Payment::Basket' to send the changes to the PSP.

If Payment has NOT been fulfilled yet then you do not need to pass a list of Item Changes to this
method as it will just send the whole Basket to the PSP. But if Payment has been Fulfilled (or
Settled) or the Shipment is an Exchange Shipment (and has commenced Packing) then you will need to
pass the list of Original Shipment Item Ids and the Item Ids of their replacements as shown above.

=cut

sub notify_psp_of_item_changes {
    my ( $self, $changes ) = @_;

    # not for Sample Shipments
    my $order = $self->order;
    return      if ( !$order );

    # only do this if the Payment Method says we should
    return      if ( !$self->should_notify_psp_when_basket_changes );

    # if Shipment is an Exchange then return here
    # unless its 'has_packing_started' flag is TRUE
    return      if ( $self->is_exchange && !$self->has_packing_started );

    my $basket = $self->get_shipment_basket_instance();
    my $has_payment_been_fulfilled = $order->order_check_payment;

    if ( $has_payment_been_fulfilled || $self->is_exchange ) {
        croak "No Item Change Array Ref. passed in to 'notify_psp_of_item_changes' when Payment has been Fulfiled"
                    if ( !$changes || ref( $changes ) ne 'ARRAY' );
        $basket->update_psp_with_item_changes( $changes );
    }
    else {
        $basket->send_basket_to_psp();
    }

    return;
}

=head2 notify_psp_of_exchanged_items

    $self->notify_psp_of_exchanged_items();

If the Order's Payment Method requires to be notified of Basket Changes this method
will send to the PSP the list of Exchanged Items along with their original Shipment
Item Id from the Original Shipment.

It will use the 'XT::Domain::Payment::Basket->update_psp_with_item_changes' method
to do this.

=cut

sub notify_psp_of_exchanged_items {
    my $self = shift;

    # only for Exchanges
    return      if ( !$self->is_exchange );

    # only for Shipments with an Order
    my $order = $self->order;
    return      if ( !$order );

    # only do this if the Payment Method says we should
    return      if ( !$self->should_notify_psp_when_basket_changes );

    my @changes_for_psp;

    my @items = $self->non_cancelled_items->all;
    foreach my $item ( @items ) {
        # there should only be One non-cancelled
        # Return Item for the Shipment Item
        my $return_item = $item->return_item_exchange_shipment_item_ids
                                ->not_cancelled
                                    ->search( {}, { order_by => 'id' } )
                                        ->first;
        # pass to the PSP the Exchange Item's original Item
        push @changes_for_psp, {
            orig_item_id => $return_item->shipment_item_id,
            new_item_id  => $item->id,
        };
    }

    # notify the PSP of any changes that it should be told about
    if ( @changes_for_psp ) {
        $self->get_shipment_basket_instance->update_psp_with_item_changes( \@changes_for_psp );
    }

    return;
}

=head2 get_payment_info_for_tt

    $hash_ref = $self->get_payment_info_for_tt;

This will return the Payment Details in regards to how the Payment was
Paid using either Credit Card or a Third Party Payment Method (PayPal)
in a Hash Ref. that can be used in Email TT files (or any other TT file
that might find it useful).

=cut

sub get_payment_info_for_tt {
    my $self = shift;

    my $order = $self->order;
    return {}   if ( !$order );

    my $info = {
        was_paid_using_credit_card => $order->is_paid_using_credit_card,
        was_paid_using_third_party => $order->is_paid_using_third_party_psp,
        # this might be useful in the future
        payment_obj                => $order->payments->first,
    };

    if ( $info->{was_paid_using_third_party} ) {
        my $third_party_payment = $order->get_third_party_payment_method;
        # get rid of whitespace and uppercase the method description
        my $method_desc = uc( $third_party_payment->payment_method );
        $method_desc    =~ s/\s//g;
        $info->{third_party_paid_with} = $method_desc;
        $info->{third_party_display_name} = $third_party_payment->display_name;

        # this might be useful in the future
        $info->{third_party_payment_obj} = $third_party_payment;
    }

    return $info;
}

=head2 fetch_third_party_klarna_invoice

Fetches the klarna invoice, where required, using the URL provided by PSP.
Any errors are ignored so that packing completes regardless.

=cut

sub fetch_third_party_klarna_invoice {
    my ( $self ) = @_;

    my $timeout  = config_var('Fulfilment', 'klarna_invoice_retrieval_timeout');
    $ua->timeout($timeout);
    my $url = $self->order->get_third_party_invoice_url() or return undef;

    my $payment_method = $self->order->get_third_party_payment_method->payment_method;
    my $file = $self->get_third_party_invoice_file_path( $url, $payment_method ) or return undef;

    # use LWP::Simple getstore method to retrieve the invoice from the url provided
    my $return_code = getstore($url, $file);
    if ( is_error( $return_code ) ) {
        xt_logger->warn("Unable to fetch third party invoice: $url");
        return $return_code;
    }
    my $dbh = $self->result_source->storage->dbh;
    log_shipment_document(
            $dbh,
            $self->id,
            "$payment_method Invoice",
            basename($file),
            '-',
    );
    xt_logger->info("Successfully retrieved third party invoice: $file");
    return $file;
}

=head2 get_third_party_invoice_file_path

Fetch the full path for the invoice, given the url and payment method for the shipment

=cut

sub get_third_party_invoice_file_path {
    my ( $self, $url, $payment_method ) = @_;
    my $filename = sprintf('invoice_%s-%i.%s',
                           lc($payment_method),
                           $self->id,
                           document_details_from_name($url)->{extension});
    my $file = path_for_print_document( document_details_from_name( $filename ) );
    return $file;
}

=head2 get_previous_non_hold_shipment_status_log_entry

    Returns last entry from shipment_status_log table excluding
    current shipment_status entry, Finance Hold, Hold, Delivered and Delivery Attempted status.

Note: Delivered and Delivery Attempted are just logs entries and not actual
    shipment Status. Warehouse team introduced it for SLA tracking, Hence excluding them.
    Also note that we are NOT excluding Return Hold and Exchange hold, DDU Hold and PreOrder Hold status.

=cut

sub get_previous_non_hold_shipment_status_log_entry  {

    my ($self) = @_;

    my $row = $self->search_related('shipment_status_logs',
    {
        shipment_status_id => { -not_in => [
                $self->shipment_status_id,
                $SHIPMENT_STATUS__DELIVERED,
                $SHIPMENT_STATUS__DELIVERY_ATTEMPTED,
                $SHIPMENT_STATUS__FINANCE_HOLD,
                $SHIPMENT_STATUS__HOLD,
            ],
       }
    },
    {
        order_by => { -desc => [ 'date', 'id'] },
        rows => 1,
    })->single;

    return $row;
}

=head2 get_shipment_sub_region

Returns the name of the sub_region for the shipment.

=cut

sub get_shipment_sub_region {
    my $self = shift;
    return $self->shipment_address->country_table->sub_region->sub_region;
}

=head2 get_priority_data

Returns data relevant to how the shipment should be prioritised for selection

 return - $current_priority : Integer value used to compare selection priority for this
  shipment to other shipments (lower value == higher priority)
  Note that, if no priority can be found, this will be set to -1 (due to TemplateToolkit
  dieing on undefined varaibles. If someone can work out why STRICT mode is turned on and
  can turn it off, please do :) )
 return - $is_bumped : Boolean, 1 if the shipment's priority value has been 'bumped'
  (e.g. it has been raised after passing the shipment's bump_deadline) or 0 if it has not

=cut
sub get_priority_data {
    my ($self) = @_;

    my $wms_bump_deadline = $self->wms_bump_deadline();

    my $is_bumped = (
        $wms_bump_deadline && DateTime->compare($self->_get_now(), $wms_bump_deadline) > -1
        ? 1
        : 0
    );

    my $current_priority = ($is_bumped
        ? $self->wms_bump_pick_priority()
        : $self->wms_initial_pick_priority()
    );

    $current_priority = -1 unless defined($current_priority);

    return ($current_priority, $is_bumped);
}

sub _get_now {
    my ($self) = @_;
    return $self->result_source->schema->db_now();
}

=head2 is_between_eu_member_states

Returns true if the shipment is between EU member states.

=cut

sub is_between_eu_member_states {
    my $self = shift;

    return 0 unless $self->shipment_address->is_eu_member_states;

    my $dc_country = config_var('DistributionCentre', 'country');

    my $schema = $self->result_source->schema;

    my $dc_sub_region_id = $schema->resultset('Public::Country')
        ->find_by_name( $dc_country )
        ->sub_region_id
    ;

    return $dc_sub_region_id == $SUB_REGION__EU_MEMBER_STATES;
}

=head2 is_dhl_dutiable

Returns boolean to determine if the shipment is dutiable by DHL's definition
as used by the Capability and Quote service.

=cut

sub is_dhl_dutiable {
    # Rules for DHL is_dutiable flag:
    #
    # A shipment is dutiable if it contains non voucher items and:
    #
    # - in DC1, the shipment is to a country outside the EU
    #
    # - in DC2 and DC3, the shipment is non-domestic
    #

    my $self = shift;

    return undef if $self->is_voucher_only;

    return ( ($self->is_international || $self->is_international_ddu) &&
           !$self->is_between_eu_member_states);

}

=head2 requires_archive_label: Bool

Returns boolean if the shipment requests archive label
Usually dutiable shipments require archive label

=cut

sub requires_archive_label {

    return !!shift->is_dhl_dutiable;
}


=head2 export_declaration_information

Returns a hashref containing the shipment item information required for DHL
export declarations for international shipments.

The information is per variant and consists of quantity, price (unit price +
tax) and the descriptiotn (shipping attribute name).

=cut

sub export_declaration_information {
    my ( $self ) = @_;

    my $data = {};

    my @shipment_items = $self->non_cancelled_items->all;
    SHIPMENT_ITEM:
    foreach my $item ( @shipment_items ) {
        next SHIPMENT_ITEM  if $item->is_virtual_voucher;
        # check if statuses are correct for check here....
        if (number_in_list($item->shipment_item_status,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                       )) {
            next SHIPMENT_ITEM
        }

        # if the item is a physical voucher, it has a nominal value of 1 (in order currency)
        my $unit_price = $item->is_physical_voucher
                         ? 1 : $item->unit_price;

        my $variant      = $item->get_true_variant;
        my $product      = $variant->product;

        # Variant already exists in export information
        if ( exists $data->{$variant->id} ) {
            $data->{$variant->id}{quantity}++;
        }
        else {
            my $si;
            $si->{quantity}    = 1;
            $si->{total_price}  = $unit_price;
            $si->{description} = $product->name;
            $data->{$variant->id} = $si;
        }
    }
    return $data;
}

=head2 get_requested_date

Return the date that this shipment was originall requested. If there is an associated
 order, it will defer to when the order was requested.

=cut
sub get_requested_date {
    my ($self) = @_;
    my $order = $self->order();
    return ( $order ? $order->date() : $self->date() );
}

=head2 get_order_number

If the shipment has an associated order, the order-number is returned.
Else undef is returned

=cut
sub get_order_number {
    my ($self) = @_;
    my $order = $self->order();
    return ( $order ? $order->order_nr() : undef );
}

=head2 contains_on_sale_items

Returns 1 if any of the shipment items were on sale (had the SALE flag in
the order file) at the time the order was made.

=cut

sub contains_on_sale_items {
    my $self = shift;

    my $count = $self->non_cancelled_items->search_related('sale_flag', {
        on_sale    => 1,
    } )->count;

    return $count > 0 ? 1 : 0;
}

=head2 retry_address_validation

Attempt to revalidate the address for the shipment if it is on hold
for an incomplete address.

=cut

sub retry_address_validation {
    my ($self, $operator_id) = @_;

    $operator_id ||= $APPLICATION_OPERATOR_ID;

    $self->result_source->schema->txn_do(
        sub{
            return if $self->has_validated_address;

            return unless $self->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS);

            $self->update_status(
                $SHIPMENT_STATUS__PROCESSING,
                $operator_id,
            );

            $self->validate_address({
                operator_id => $operator_id,
            });

            $self->discard_changes;

            $self->hold_if_invalid({
                operator_id => $operator_id,
            });

            $self->discard_changes;
        },
    );
}

=head2 select( operator_id, msg_factory? ) : Bool

Select the shipment. Will create a default message factory if you don't pass
one explicitly. Will return a false value if there are no items to select, and
will die on error.

=cut

sub select {
    my ( $self, $operator_id, $msg_factory ) = @_;

    croak 'Pick Scheduler manages selection when we have PRLs'
        if XT::Warehouse->instance->has_prls;

    # check the shipment has items in NEW status (to stop things being printed
    # twice i.e. page refresh). Maybe we should be stricter here and die, as we
    # are for when we hold a shipment. Adding some logging to see if this ever
    # happens.
    my @items = $self->unselected_items->all;
    unless ( @items ) {
        xt_logger->warn(sprintf
            q{Attempted to select shipment '%i' even though there were no unselected items},
            $self->id
        );
        return undef;
    }

    # Die if we've attempted to select a shipment that's on hold
    die sprintf( q{Shipment '%i' is on hold}, $self->id ) if $self->is_on_hold;

    # update status of items from 'New' to 'Selected'
    $_->set_selected($operator_id) for @items;

    # Notify anyone who cares about stock levels
    $self->broadcast_stock_levels;

    # Send shipment request message to WMS to print the picking list, except if
    # it's a virtual voucher (no picking required)
    return 1 if $self->is_virtual_voucher_only;

    $msg_factory //= $self->msg_factory;
    $msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::ShipmentRequest', $self
    );

    return 1;
}

=head2 requires_gift_message_warning() : Bool

True if this shipment requires a gift message warning to be printed.

=cut

sub requires_gift_message_warning {
    my $self = shift;
    return !$self->can_automate_gift_message && $self->has_gift_messages;
}

=head2 requires_dangerous_goods_note() : Bool

True if this shipment requires a dangerous goods note to be printed.

=cut

sub requires_dangerous_goods_note {
    my $self = shift;
    return config_var('Print_Document', 'requires_dangerous_goods_note')
        && !$self->is_premier
        && $self->has_hazmat_lq_items;
}

=head2 get_allowed_value_of_signature_required_flag_for_address

Returns Value [ 1 or 0] of signature_required flag to be set based on business logic rule:
'Shipment::get_allowed_value_of_shipment_signature_required_flag_for_address'

=cut

sub get_allowed_value_of_signature_required_flag_for_address {
    my ( $self, $args) = @_;

    my $schema  = $self->result_source->schema;
    my $country = $schema->resultset('Public::Country')->search({
        country => { 'ILIKE' => $args->{address}->{country} }
    })->first;

    $args->{address}->{country_code} = $country->code;
    $args->{address}->{sub_region}   = $country->sub_region->sub_region;

    # the 'urn' is sometimes an 'XT::Data::URI' object and it
    # doesn't stringify when going through 'XT::Rules' and
    # throws a fatal error, so forcing it to stringify here
    $args->{address}{urn} .= ""     if ( $args->{address}{urn} );

    return XT::Rules::Solve->solve( 'Shipment::get_allowed_value_of_shipment_signature_required_flag_for_address' => {
        department_id           => $args->{department_id},
        signature_required_flag => $self->signature_required,
        address_ref             => $args->{address},
    } );
}

=head2 shipment_general_hold_description

Returns a description of the type of hold the shipment is on, if there is one,
otherwise it returns the current shipment status.

    my $hold_description = $schema->resultet('Public::Shipment')
        ->find( $id )
        ->shipment_general_hold_description;

=cut

sub shipment_general_hold_description {
    my $self = shift;

    my $shipment_hold = $self->shipment_holds
        ->search( undef, { order_by => { -desc => 'id' } } )
        ->first;

    return $shipment_hold
        ? $shipment_hold->shipment_hold_reason->reason
        : $self->shipment_status->status;

}

=head2 allow_editing_of_shipping_address_post_settlement

    $boolean = $self->allow_editing_of_shipping_address_post_settlement();

Returns TRUE or FALSE based on whether the Payment Method for the
Order is allowed to edit shipping address for Settled Payment.

If the Shipment is NOT linked to an Order (such as a Sample) then
this method will return TRUE.

=cut

sub allow_editing_of_shipping_address_post_settlement {
    my $self = shift;

    my $order = $self->order;
    return 1 if( !$order );

    return $order->payment_method_allow_editing_of_shipping_address_post_settlement;
}

=head2 calculate_shipping_tax

    Given grand_total it returns shipping tax for the shipment.

    $tax = $self->calculate_shipping_tax($total_amount_paid);

=cut

sub calculate_shipping_tax {
    my $self        = shift;
    my $grand_total = shift;

    my $tax_rate         = 0;
    my $order_threshold  = 0;
    my $shipping_tax     = 0;
    my $country          = $self->shipment_address->country_ignore_case;
    my $country_tax_rate = $country->country_tax_rate;

    if( $country_tax_rate ) {
        my $country_tax_code = $country->search_related(
            'country_tax_codes', { channel_id => $self->order->channel_id }
        )->first;

        $tax_rate = $country_tax_rate->rate;
    }

    # see if there is an order threshold rule
    my $country_tax_rules = $country->tax_rule_values;
    while (my $country_tax_rule = $country_tax_rules->next) {
        if ($country_tax_rule->tax_rule->rule eq 'Order Threshold') {
            $order_threshold = $country_tax_rule->value;
        }
    }

    if( $tax_rate && $grand_total >  $order_threshold ) {
        $shipping_tax = $self->shipping_charge -
        (
            $self->shipping_charge / ( 1 + $tax_rate )
        );
        $shipping_tax = sprintf("%.2f", $shipping_tax);
        if( $shipping_tax eq '-0.00') {
            $shipping_tax = '0.00';
        }
    }

    return $shipping_tax;
}

=head2 get_shipment_basket

    ArrayofHash = $self->get_shipment_basket;

Returns AoH containing data of shipment_items, virtual_voucher,
store credit and Shipping line item. To consturct basket it
uses XT::Domain::Payment::Basket.

=cut

sub get_shipment_basket {
    my $self = shift;

   return $self->get_shipment_basket_instance->construct_basket_for_psp;

}

=head2 get_shipment_basket_instance

    $object = $self->get_shipment_basket_instance

Return instance of XT::Domain::Payment::Basket

=cut

sub get_shipment_basket_instance {
    my $self =  shift;

    return  XT::Domain::Payment::Basket->new( {
        shipment => $self
    });
}

=head2 hold_if_invalid_address_characters($operator_id) : Bool

Place this shipment on hold if it has invalid characters - to be used for DHL,
which doesn't support non-Latin-1 characters in the address. Returns true if
the shipment was placed on hold.

=cut

sub hold_if_invalid_address_characters {
    my ( $self, $operator_id ) = @_;

    return undef unless $self->shipment_address->has_non_latin_1_characters;

    $self->set_status_hold(
        $operator_id,
        $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
        "Address contains characters we cannot send to the carrier"
    );
    return 1;
}
=head2 should_print_invoice

    We do not need to print invoice for payment methods like Klarna.
    The condition is stored in boolean column produce_customer_invoice_at_fulfilment

=cut
sub should_print_invoice {
    my $self = shift;

    # always print invoice by default
    my $status = 1;

    # sample shipments do not have any orders
    return $status if (! $self->order);

    try {
        $status = $self->order->get_third_party_payment_method->produce_customer_invoice_at_fulfilment;
    } catch {
        xt_logger("Order number " . $self->order->order_nr . " does not have third party payment method: $_");
    };
    return $status;
}

=head2 should_cancel_payment_after_forced_address_update

    $boolean = $self->should_cancel_payment_after_forced_address_update();

Returns TRUE or FALSE based on whether the Payment Method for the
Order requires that the Payment be Cancelled if the Shipping Address is
updated with 'force' when Editing the Shipping Address.

If the Shipment is NOT linked to an Order (such as a Sample) then
this method will return FALSE.

=cut

sub should_cancel_payment_after_forced_address_update {
    my $self = shift;

    my $order = $self->order;
    return 0    if( !$order );

    return $order->payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used();
}

1;

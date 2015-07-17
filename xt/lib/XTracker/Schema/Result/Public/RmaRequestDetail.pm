use utf8;
package XTracker::Schema::Result::Public::RmaRequestDetail;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rma_request_detail");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "rma_request_detail_id_seq",
  },
  "rma_request_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rtv_quantity_id",
  { data_type => "integer", is_nullable => 0 },
  "delivery_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "fault_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fault_description",
  { data_type => "varchar", is_nullable => 1, size => 2000 },
  "type_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "delivery_item",
  "XTracker::Schema::Result::Public::DeliveryItem",
  { id => "delivery_item_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "fault_type",
  "XTracker::Schema::Result::Public::ItemFaultType",
  { id => "fault_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "rma_request",
  "XTracker::Schema::Result::Public::RmaRequest",
  { id => "rma_request_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "rma_request_detail_status_logs",
  "XTracker::Schema::Result::Public::RmaRequestDetailStatusLog",
  { "foreign.rma_request_detail_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_shipment_details",
  "XTracker::Schema::Result::Public::RTVShipmentDetail",
  { "foreign.rma_request_detail_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yW1XL7GYRHU6/HDWWsADjQ

use XTracker::Constants::FromDB qw/:rma_request_detail_status/;

=head1 PUBLIC METHODS

=head2 is_rtv

Returns true if this stock has been (or has been identified to be)
returned to vendor

=cut
sub is_rtv {
    my ($self) = @_;
    return (
        $self->status_id() == $RMA_REQUEST_DETAIL_STATUS__RTV
        ? 1
        : 0
    )
}

1;

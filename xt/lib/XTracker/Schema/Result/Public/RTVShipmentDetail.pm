use utf8;
package XTracker::Schema::Result::Public::RTVShipmentDetail;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rtv_shipment_detail");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "rtv_shipment_detail_id_seq",
  },
  "rtv_shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rma_request_detail_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "rma_request_detail",
  "XTracker::Schema::Result::Public::RmaRequestDetail",
  { id => "rma_request_detail_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "rtv_shipment",
  "XTracker::Schema::Result::Public::RTVShipment",
  { id => "rtv_shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nAO4Lg2bfsu904WgizeEDw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

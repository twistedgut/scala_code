use utf8;
package XTracker::Schema::Result::Public::RTVInspectionPickRequestDetail;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rtv_inspection_pick_request_detail");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "rtv_inspection_pick_request_detail_id_seq",
  },
  "rtv_inspection_pick_request_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rtv_quantity_id",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "rtv_inspection_pick_request",
  "XTracker::Schema::Result::Public::RTVInspectionPickRequest",
  { id => "rtv_inspection_pick_request_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Msdvnm29tUwnq1QnrNr85w

# This relation is not present in the db as rtv_quantity entries get deleted,
# but should still be useful here
__PACKAGE__->belongs_to(
    'rtv_quantity' => 'Public::RTVQuantity',
    { 'foreign.id' => 'self.rtv_quantity_id' },
);

1;

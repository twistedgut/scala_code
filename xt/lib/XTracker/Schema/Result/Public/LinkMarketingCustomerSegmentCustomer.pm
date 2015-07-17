use utf8;
package XTracker::Schema::Result::Public::LinkMarketingCustomerSegmentCustomer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_marketing_customer_segment__customer");
__PACKAGE__->add_columns(
  "customer_segment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "customer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->add_unique_constraint(
  "link_marketing_customer_segme_customer_segment_id_customer__key",
  ["customer_segment_id", "customer_id"],
);
__PACKAGE__->belongs_to(
  "customer",
  "XTracker::Schema::Result::Public::Customer",
  { id => "customer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customer_segment",
  "XTracker::Schema::Result::Public::MarketingCustomerSegment",
  { id => "customer_segment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rTn9twfzcCRz1GOeDVk7yQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

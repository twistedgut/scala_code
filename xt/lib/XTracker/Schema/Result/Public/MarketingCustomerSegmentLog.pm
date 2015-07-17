use utf8;
package XTracker::Schema::Result::Public::MarketingCustomerSegmentLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.marketing_customer_segment_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "marketing_customer_segment_log_id_seq",
  },
  "customer_segment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "enabled_state",
  { data_type => "boolean", is_nullable => 1 },
  "date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "customer_segment",
  "XTracker::Schema::Result::Public::MarketingCustomerSegment",
  { id => "customer_segment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6lLJKKCDtYC+Ai5oUN2Fhw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
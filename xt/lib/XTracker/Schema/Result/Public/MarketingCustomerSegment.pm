use utf8;
package XTracker::Schema::Result::Public::MarketingCustomerSegment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.marketing_customer_segment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "marketing_customer_segment_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "created_date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "job_queue_flag",
  { data_type => "boolean", is_nullable => 1 },
  "date_of_last_jq",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "marketing_customer_segment_name_channel_id_key",
  ["name", "channel_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_marketing_customer_segment__customers",
  "XTracker::Schema::Result::Public::LinkMarketingCustomerSegmentCustomer",
  { "foreign.customer_segment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__customer_segments",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionCustomerSegment",
  { "foreign.customer_segment_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_customer_segment_logs",
  "XTracker::Schema::Result::Public::MarketingCustomerSegmentLog",
  { "foreign.customer_segment_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cHK10uN+XIT8YFrUe/sXKg


=head2 get_customer_count

    my $count = $marketing_customer_segment->get_customer_count();

Returns count of customers attached to customer_segment

=cut

sub get_customer_count {
    my $self = shift;

    return ($self->link_marketing_customer_segment__customers->count);
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

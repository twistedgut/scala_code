use utf8;
package XTracker::Schema::Result::Public::LogStock;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.log_stock");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "log_stock_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_nullable => 0 },
  "stock_action_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "notes",
  { data_type => "text", is_nullable => 1 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "balance",
  { data_type => "integer", is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp(6) with time zone",
    is_nullable   => 0,
  },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:p4VxCjH28ojLXGOe1jN/LQ

__PACKAGE__->might_have(
  "product_variant",
  "XTracker::Schema::Result::Public::Variant",
  { "foreign.id" => "self.variant_id" },
);
__PACKAGE__->might_have(
  "voucher_variant",
  "XTracker::Schema::Result::Voucher::Variant",
  { "foreign.id" => "self.variant_id" },
);

=head2 variant

Returns a Voucher or a Product variant

=cut

sub variant {
    return $_[0]->product_variant || $_[0]->voucher_variant;
}

1;

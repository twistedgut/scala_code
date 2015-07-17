use utf8;
package XTracker::Schema::Result::Public::LogRtvStock;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.log_rtv_stock");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "log_rtv_stock_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "rtv_action_id",
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
    default_value => \"('now'::text)::timestamp without time zone",
    is_nullable   => 0,
  },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "voucher_variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
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
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "voucher_variant",
  "XTracker::Schema::Result::Voucher::Variant",
  { id => "voucher_variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xh6fKNH8RjfsKYyNC4W3dQ


__PACKAGE__->belongs_to(
  "product_variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
);


=head2 variant

Call the product or voucher variant for this object.

=cut
{
    no warnings "redefine";
    *variant = sub {
        return $_[0]->product_variant || $_[0]->voucher_variant;
    };
}


1;

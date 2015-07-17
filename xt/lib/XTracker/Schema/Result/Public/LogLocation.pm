use utf8;
package XTracker::Schema::Result::Public::LogLocation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.log_location");
__PACKAGE__->add_columns(
  "variant_id",
  { data_type => "integer", is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp(6) with time zone",
    is_nullable   => 0,
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "log_location_id_seq",
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "location",
  "XTracker::Schema::Result::Public::Location",
  { id => "location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sPGBw5j5K3OG6mRkVEvtBQ

__PACKAGE__->might_have(
    'product_variant' => 'XTracker::Schema::Result::Public::Variant',
    { 'foreign.id' => 'self.variant_id' },
);

__PACKAGE__->might_have(
    'voucher_variant' => 'XTracker::Schema::Result::Voucher::Variant',
    { 'foreign.id' => 'self.variant_id' },
);


=head2 variant

Return a product or voucher variant.

=cut

sub variant {
    return $_[0]->product_variant || $_[0]->voucher_variant;
}

1;

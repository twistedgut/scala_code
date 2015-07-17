use utf8;
package XTracker::Schema::Result::Public::Putaway;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.putaway");
__PACKAGE__->add_columns(
  "stock_process_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "timestamp",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp(6) with time zone",
    is_nullable   => 0,
  },
  "complete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "putaway_id_seq",
  },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("stock_process_id", "location_id");
__PACKAGE__->belongs_to(
  "location",
  "XTracker::Schema::Result::Public::Location",
  { id => "location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "stock_process",
  "XTracker::Schema::Result::Public::StockProcess",
  { id => "stock_process_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:D/B5ZM7GbQ9u5Cs8zzg2Wg

=head2 channel

Returns the channel for this putaway, via stock process. This is used to determine
valid putaway locations in DC2.5.

=cut

sub channel {
    my ($self) = @_;

    return $self->stock_process->channel;
}

1;

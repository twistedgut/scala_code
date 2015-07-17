use utf8;
package XTracker::Schema::Result::Public::LocalExchangeRate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.local_exchange_rate");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "local_exchange_rate_id_seq",
  },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rate",
  { data_type => "numeric", is_nullable => 0, size => [12, 3] },
  "start_date",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp(0) with time zone",
    is_nullable   => 0,
  },
  "end_date",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zZsK/gbHfr1p3HeCUmdmiQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

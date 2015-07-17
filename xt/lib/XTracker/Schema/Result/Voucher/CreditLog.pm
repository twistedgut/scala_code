use utf8;
package XTracker::Schema::Result::Voucher::CreditLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("voucher.credit_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "voucher.credit_log_id_seq",
  },
  "code_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "spent_on_shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "delta",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "logged",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "code",
  "XTracker::Schema::Result::Voucher::Code",
  { id => "code_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "spent_on_shipment_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jcr//SxLF6w9uoNKvUHB+A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

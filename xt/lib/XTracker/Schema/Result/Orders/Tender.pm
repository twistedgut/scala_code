use utf8;
package XTracker::Schema::Result::Orders::Tender;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.tender");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.tender_id_seq",
  },
  "order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "voucher_code_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "rank",
  { data_type => "integer", is_nullable => 0 },
  "value",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "order",
  "XTracker::Schema::Result::Public::Orders",
  { id => "order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "renumeration_tenders",
  "XTracker::Schema::Result::Public::RenumerationTender",
  { "foreign.tender_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::RenumerationType",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "voucher_instance",
  "XTracker::Schema::Result::Voucher::Code",
  { id => "voucher_code_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:y5rKe/69M3vc/Zjo+Lh3WQ

use XTracker::SchemaHelper qw(:records);
use XTracker::Constants::FromDB qw(
    :renumeration_type
);

__PACKAGE__->many_to_many('renumerations' => 'renumeration_tenders', 'renumeration');

sub remaining_value {
    my ($self) = @_;

    # We can calculate the remaining value by using the renumeration_tenders table
    my $rval = $self->value;

    for my $tr ($self->renumeration_tenders) {
        next if $tr->renumeration->is_cancelled;
        $rval -= $tr->value;
    }

    return $rval;
}

sub voucher_code { $_[0]->voucher_instance; }

1;

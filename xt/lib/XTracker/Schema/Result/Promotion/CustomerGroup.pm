use utf8;
package XTracker::Schema::Result::Promotion::CustomerGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.customer_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.customer_group_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("customer_group_name_key", ["name"]);
__PACKAGE__->has_many(
  "customers",
  "XTracker::Schema::Result::Promotion::CustomerCustomerGroup",
  { "foreign.customergroup_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_promotions",
  "XTracker::Schema::Result::Promotion::DetailCustomerGroup",
  { "foreign.customergroup_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:O5qkR2hxeM3qasKyS7UoVA

__PACKAGE__->add_unique_constraint(
    'join_data' => [qw/name/]
);

use XTracker::SchemaHelper qw(:records);

sub get_promotions {
    my ( $self ) = @_;

    return $self->detail_promotions->related_resultset( 'detail' );
}

1;

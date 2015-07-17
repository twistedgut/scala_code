use utf8;
package XTracker::Schema::Result::Promotion::Website;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.website");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.website_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("website_name_key", ["name"]);
__PACKAGE__->has_many(
  "customer_customergroups",
  "XTracker::Schema::Result::Promotion::CustomerCustomerGroup",
  { "foreign.website_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_websites",
  "XTracker::Schema::Result::Promotion::DetailWebsites",
  { "foreign.website_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZAqPq+NFpyWuspL1Ym5q2g

__PACKAGE__->many_to_many(
    details => 'detail_websites' => 'detail'
);

1;

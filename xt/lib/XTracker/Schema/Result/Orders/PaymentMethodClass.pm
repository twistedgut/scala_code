use utf8;
package XTracker::Schema::Result::Orders::PaymentMethodClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("orders.payment_method_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orders.payment_method_class_id_seq",
  },
  "payment_method_class",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "payment_method_class_payment_method_class_key",
  ["payment_method_class"],
);
__PACKAGE__->has_many(
  "payment_methods",
  "XTracker::Schema::Result::Orders::PaymentMethod",
  { "foreign.payment_method_class_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TqIgS8i8ptPmGMiBlmDs0A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

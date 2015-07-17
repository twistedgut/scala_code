use utf8;
package XTracker::Schema::Result::Public::PurchaseOrderNotEditableInFulcrum;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.purchase_orders_not_editable_in_fulcrum");
__PACKAGE__->add_columns("number", { data_type => "text", is_nullable => 0 });
__PACKAGE__->set_primary_key("number");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:abImtFml7dGyM59OgpVwhA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

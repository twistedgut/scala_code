use utf8;
package XTracker::Schema::Result::Public::DblSubmitToken;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.dbl_submit_token");
__PACKAGE__->add_columns("id", { data_type => "integer", is_nullable => 0 });
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gt5Hqm31+e8CLaT5/XIM4g


# You can replace this text with custom code or comments, and it will be preserved on regeneration

1;

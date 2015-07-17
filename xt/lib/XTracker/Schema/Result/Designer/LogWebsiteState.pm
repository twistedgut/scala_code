use utf8;
package XTracker::Schema::Result::Designer::LogWebsiteState;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("designer.log_website_state");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designer.log_website_state_id_seq",
  },
  "designer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "from_value",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "to_value",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "designer",
  "XTracker::Schema::Result::Public::Designer",
  { id => "designer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "from_state",
  "XTracker::Schema::Result::Designer::WebsiteState",
  { id => "from_value" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "to_state",
  "XTracker::Schema::Result::Designer::WebsiteState",
  { id => "to_value" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6URSx5Rci+DXo6srUUrENw

# Make a new ResultSource based on class
my $source = __PACKAGE__->result_source_instance();
my $new_source = $source->new( $source );
$new_source->source_name( 'WebsiteStateLog' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
( select l.id, l.date, d.designer, op.name as operator_name, wsfrom.state as from_state, wsto.state as to_state
        from designer.log_website_state l, designer d, operator op, designer.website_state wsfrom, designer.website_state wsto
        where l.designer_id = d.id
        and l.operator_id = op.id
        and l.from_value = wsfrom.id
        and l.to_value = wsto.id
        and l.date > ? )
");

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'WebsiteStateLog' => $new_source );

1;

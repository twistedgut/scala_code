use utf8;
package XTracker::Schema::Result::Product::LogNavigationTree;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("product.log_navigation_tree");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product.log_navigation_tree_id_seq",
  },
  "navigation_tree_id",
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
  "action",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "navigation_tree",
  "XTracker::Schema::Result::Product::NavigationTree",
  { id => "navigation_tree_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wdU2IA2GYeUWGbA2R3pBSA

# Make a new ResultSource based on class
my $source = __PACKAGE__->result_source_instance();
my $new_source = $source->new( $source );
$new_source->source_name( 'NavigationTreeLog' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
( select lnt.id, lnt.date, lnt.action, op.name as operator_name, attr.name as node_name, attrp.name as parent_node_name, ch.name as sales_channel, attr.channel_id
                    from product.log_navigation_tree lnt, operator op, product.navigation_tree nt, product.attribute attr, product.navigation_tree ntp, product.attribute attrp, channel ch
                    where lnt.operator_id = op.id
                    and lnt.navigation_tree_id = nt.id
                    and nt.attribute_id = attr.id
                    and nt.parent_id = ntp.id
                    and ntp.attribute_id = attrp.id
                    and attr.channel_id = ch.id
                    and lnt.date > ? )
");

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'NavigationTreeLog' => $new_source );

1;

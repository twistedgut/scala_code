use utf8;
package XTracker::Schema::Result::Product::NavigationTree;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("product.navigation_tree");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product.navigation_tree_id_seq",
  },
  "attribute_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "parent_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "sort_order",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "visible",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "feature_product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "feature_product_image",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "navigation_tree_attribute_id_key",
  ["attribute_id", "parent_id"],
);
__PACKAGE__->belongs_to(
  "attribute",
  "XTracker::Schema::Result::Product::Attribute",
  { id => "attribute_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "child_trees",
  "XTracker::Schema::Result::Product::NavigationTree",
  { "foreign.parent_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "feature_product",
  "XTracker::Schema::Result::Public::Product",
  { id => "feature_product_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "log_navigation_trees",
  "XTracker::Schema::Result::Product::LogNavigationTree",
  { "foreign.navigation_tree_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "navigation_tree_locks",
  "XTracker::Schema::Result::Product::NavigationTreeLock",
  { "foreign.navigation_tree_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "parent_tree",
  "XTracker::Schema::Result::Product::NavigationTree",
  { id => "parent_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TOC5Z3XOfFB7Nz1qIZbyyA

# duplicate of "attribute"
__PACKAGE__->belongs_to(
    'attribute_parent' => 'XTracker::Schema::Result::Product::Attribute',
    { 'foreign.id' => 'self.attribute_id' },
);

# wrong, and apparently unused
__PACKAGE__->belongs_to(
    'child_tree' => 'XTracker::Schema::Result::Product::NavigationTree',
    { 'foreign.parent_id' => 'self.id' },
    { join_type => "LEFT" },
);

use XTracker::Constants::FromDB qw( :product_attribute_type );

# Make a new ResultSource based on the Tree class
my $source = __PACKAGE__->result_source_instance();
my $new_source = $source->new( $source );
$new_source->source_name( 'TreeBranches' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
( SELECT tree.id, tree.attribute_id, attribute.name, attribute_type.name as type, parent_tree.id AS parent_node_id, sum( CASE WHEN child_tree.deleted IS false THEN 1 ELSE 0 END ) AS num_children, tree.visible
    FROM product.navigation_tree tree
        LEFT JOIN product.navigation_tree parent_tree ON ( parent_tree.id = tree.parent_id )
        LEFT JOIN product.navigation_tree child_tree ON ( child_tree.parent_id = tree.id ),
        product.attribute attribute, product.attribute_type attribute_type
        WHERE tree.deleted = false
        AND tree.parent_id = ?
        AND tree.attribute_id = attribute.id
        AND attribute.attribute_type_id = attribute_type.id
    GROUP BY tree.id, tree.attribute_id, attribute.name, attribute_type.name, parent_tree.id, tree.visible, tree.sort_order
    ORDER BY tree.sort_order)
");

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'TreeBranches' => $new_source );


# Make a new ResultSource based on the Tree class
$source = __PACKAGE__->result_source_instance();
$new_source = $source->new( $source );
$new_source->source_name( 'TreeLeaves' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
( select tree.id, tree.attribute_id, tree.feature_product_id, tree.feature_product_image, attribute.name, attribute.synonyms, attribute_type.name as type, parent_tree.id as parent_node_id, sum( case when pch.live = true and pch.visible = true then 1 else 0 end ) as num_live_prods, sum( case when p.id is not null then 1 else 0 end ) as num_prods, tree.visible
            from product.navigation_tree tree, product.navigation_tree parent_tree, product.attribute attribute
                join channel c ON c.id = attribute.channel_id
                join business b ON b.id = c.business_id
                left join product.attribute_value pc on attribute.id = pc.attribute_id
                    and pc.deleted is false
                    and pc.product_id in (select product_id from product.attribute_value where deleted is false and attribute_id = (select attribute_id from product.navigation_tree where id = ?))
                    and pc.product_id in (select product_id from product.attribute_value where deleted is false and attribute_id = (select attribute_id from product.navigation_tree where id = ?))

                left join product p on pc.product_id = p.id and (
                    (b.show_sale_products = false and p.id not in (select product_id from price_adjustment where percentage > 0 and current_timestamp between date_start and date_finish))
                    or (b.show_sale_products = true )
                )
                left join product_channel pch on pch.product_id = p.id and pch.channel_id = c.id,

                product.attribute_type attribute_type
            where tree.parent_id = ?
            and tree.deleted = false
            and tree.attribute_id = attribute.id
            and attribute.attribute_type_id = attribute_type.id
            and tree.parent_id = parent_tree.id
            group by tree.id, tree.attribute_id, tree.feature_product_id, tree.feature_product_image, attribute.name, attribute.synonyms, attribute_type.name, parent_tree.id, tree.visible, tree.sort_order
            order by tree.sort_order asc)
");

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'TreeLeaves' => $new_source );


# Make a new ResultSource based on the Tree class
$source = __PACKAGE__->result_source_instance();
$new_source = $source->new( $source );
$new_source->source_name( 'TreeStructure' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
( select ra.id as root_id, ra.name as root_name, ba.id as branch_id, ba.name as branch_name, la.id as leaf_id, la.name as leaf_name, ra.channel_id as channel_id
                        from product.navigation_tree rt, product.attribute ra, product.navigation_tree bt, product.attribute ba, product.navigation_tree lt, product.attribute la
                        where rt.deleted = false
                        and rt.attribute_id = ra.id
                        and ra.attribute_type_id = $PRODUCT_ATTRIBUTE_TYPE__CLASSIFICATION
                        and rt.id = bt.parent_id
                        and bt.deleted = false
                        and bt.attribute_id = ba.id
                        and ba.attribute_type_id = $PRODUCT_ATTRIBUTE_TYPE__PRODUCT_TYPE
                        and bt.id = lt.parent_id
                        and lt.deleted = false
                        and lt.attribute_id = la.id
                        and la.attribute_type_id = $PRODUCT_ATTRIBUTE_TYPE__SUB_DASH_TYPE )
");

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'TreeStructure' => $new_source );


# Make a new ResultSource based on the Tree class
$source = __PACKAGE__->result_source_instance();
$new_source = $source->new( $source );
$new_source->source_name( 'ProductAttributeTree' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
( select p.id, pc.live as live, pc.visible as visible, rav.attribute_id as root_id, ra.name as root_name, bav.attribute_id as branch_id, ba.name as branch_name, lav.attribute_id as leaf_id, la.name as leaf_name, ra.channel_id as channel_id
                        from product p, product.attribute_value rav, product.attribute ra, product.attribute_value bav, product.attribute ba, product.attribute_value lav, product.attribute la,
                        product_channel pc,
                        channel c,
                        business b
where p.id = rav.product_id
and pc.product_id = p.id
and pc.channel_id = ra.channel_id
and c.id = pc.channel_id
and b.id = c.business_id
and rav.deleted = false
and rav.attribute_id = ra.id
and ra.attribute_type_id = $PRODUCT_ATTRIBUTE_TYPE__CLASSIFICATION
and p.id = bav.product_id
and bav.deleted = false
and bav.attribute_id = ba.id
and ba.attribute_type_id = $PRODUCT_ATTRIBUTE_TYPE__PRODUCT_TYPE
and p.id = lav.product_id
and lav.deleted = false
and lav.attribute_id = la.id
and la.attribute_type_id = $PRODUCT_ATTRIBUTE_TYPE__SUB_DASH_TYPE
and (
    (b.show_sale_products = false and p.id not in (select product_id from price_adjustment where percentage > 0 and current_timestamp between date_start and date_finish) )
    or (b.show_sale_products = true))
)
");

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'ProductAttributeTree' => $new_source );


1; # be true

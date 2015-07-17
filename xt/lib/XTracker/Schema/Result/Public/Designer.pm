use utf8;
package XTracker::Schema::Result::Public::Designer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.designer");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designer_id_seq",
  },
  "designer",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "url_key",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("designer_designer_key", ["designer"]);
__PACKAGE__->has_many(
  "attribute_values",
  "XTracker::Schema::Result::Designer::AttributeValue",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "designer_channels",
  "XTracker::Schema::Result::Public::DesignerChannel",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "legacy_designer_supplier",
  "XTracker::Schema::Result::Public::LegacyDesignerSupplier",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__designers",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionDesigner",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_designer_descriptions",
  "XTracker::Schema::Result::Public::LogDesignerDescription",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_website_states",
  "XTracker::Schema::Result::Designer::LogWebsiteState",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_detail_designers",
  "XTracker::Schema::Result::Promotion::DetailDesigners",
  { "foreign.designer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "purchase_orders",
  "XTracker::Schema::Result::Public::PurchaseOrder",
  { "foreign.designer_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:r0o7LaN1dF93jicCKlZOlA

# TODO: Replace all instances of this with designer_channels
__PACKAGE__->has_many(
    'designer_channel' => 'Public::DesignerChannel',
    { 'foreign.designer_id' => 'self.id' },
);

__PACKAGE__->has_many(
    'legacy_designer_suppliers' => 'Public::LegacyDesignerSupplier',
    { 'foreign.designer_id' => 'self.id' },
);

__PACKAGE__->many_to_many(
    'suppliers' => 'legacy_designer_suppliers' => 'supplier'
);

__PACKAGE__->many_to_many(
    channels => 'designer_channels' => 'channel'
);

# Make a new ResultSource based on the Designer class
my $source = __PACKAGE__->result_source_instance();
my $new_source = $source->new( $source );
$new_source->source_name( 'DesignerState' );

# set up query - acts like a subselect after the FROM clause
$new_source->name( "
(SELECT designer,
        channel_id,
        state,
        SUM(num_products) AS num_products,
        SUM(num_comingsoon) AS num_comingsoon
FROM (
    SELECT d.designer AS designer,
           dc.channel_id AS channel_id,
           ds.state AS state,
           SUM(CASE WHEN pc.visible = true THEN 1 ELSE 0 END) AS num_products,
           0 AS num_comingsoon
    FROM      designer d
    JOIN      designer_channel dc ON d.id = dc.designer_id
    LEFT JOIN product p           ON d.id = p.designer_id
    LEFT JOIN product_channel pc  ON p.id = pc.product_id AND pc.channel_id = dc.channel_id,
    designer.website_state ds
    WHERE dc.website_state_id = ds.id
    GROUP BY 1,2,3
UNION ALL
    SELECT d.designer AS designer,
           dc.channel_id AS channel_id,
           ds.state AS state,
           0 AS num_products,
           SUM(CASE WHEN so.cancel = false AND so.status_id = 1 THEN 1 ELSE 0 END) AS num_comingsoon
    FROM designer d
    JOIN designer_channel dc ON d.id = dc.designer_id
    JOIN product p           ON p.designer_id = d.id
    JOIN stock_order so      ON so.product_id = p.id
    JOIN purchase_order po   ON po.id = so.purchase_order_id
    AND po.season_id IN (
        SELECT id
        FROM season
        WHERE id != 0
        AND   season_year >= DATE_PART('year', current_timestamp)
    )
    AND po.channel_id = dc.channel_id,
        designer.website_state ds
    WHERE dc.website_state_id = ds.id
    GROUP BY 1,2,3
    ) AS grouping
GROUP BY 1,2,3)
" );
$new_source->resultset_class( 'XTracker::Schema::ResultSet::Public::Designer' );

# register new ResultSource with Schema
XTracker::Schema->register_extra_source( 'DesignerState' => $new_source );

1;

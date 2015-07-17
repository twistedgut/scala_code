use utf8;
package XTracker::Schema::Result::Public::Product;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.product");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product_id_seq",
  },
  "world_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "designer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "division_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "classification_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "product_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "sub_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "colour_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "style_number",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "season_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "hs_code_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "note",
  { data_type => "text", is_nullable => 1 },
  "legacy_sku",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "colour_filter_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "payment_term_id",
  { data_type => "integer", default_value => 1, is_nullable => 1 },
  "payment_settlement_discount_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "payment_deposit_id",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "watch",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_nullable => 1 },
  "storage_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "canonical_product_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->might_have(
  "attribute",
  "XTracker::Schema::Result::Public::ProductAttribute",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "attribute_value",
  "XTracker::Schema::Result::Product::AttributeValue",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfers",
  "XTracker::Schema::Result::Public::ChannelTransfer",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "classification",
  "XTracker::Schema::Result::Public::Classification",
  { id => "classification_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "colour",
  "XTracker::Schema::Result::Public::Colour",
  { id => "colour_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "colour_filter",
  "XTracker::Schema::Result::Public::ColourFilter",
  { id => "colour_filter_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "contents",
  "XTracker::Schema::Result::WebContent::Content",
  { "foreign.searchable_product_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "designer",
  "XTracker::Schema::Result::Public::Designer",
  { id => "designer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "division",
  "XTracker::Schema::Result::Public::Division",
  { id => "division_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "external_image_urls",
  "XTracker::Schema::Result::Product::ExternalImageUrl",
  { "foreign.product_id" => "self.id" },
  { order_by => { -asc => "id" } },
);
__PACKAGE__->belongs_to(
  "hs_code",
  "XTracker::Schema::Result::Public::HSCode",
  { id => "hs_code_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_product__ship_restrictions",
  "XTracker::Schema::Result::Public::LinkProductShipRestriction",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "navigation_trees",
  "XTracker::Schema::Result::Product::NavigationTree",
  { "foreign.feature_product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_adjustments",
  "XTracker::Schema::Result::Public::PriceAdjustment",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_country",
  "XTracker::Schema::Result::Public::PriceCountry",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "price_default",
  "XTracker::Schema::Result::Public::PriceDefault",
  { "foreign.product_id" => "self.id" },
  { join_type => "INNER" },
);
__PACKAGE__->might_have(
  "price_purchase",
  "XTracker::Schema::Result::Public::PricePurchase",
  { "foreign.product_id" => "self.id" },
  { join_type => "INNER" },
);
__PACKAGE__->has_many(
  "price_region",
  "XTracker::Schema::Result::Public::PriceRegion",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_channel",
  "XTracker::Schema::Result::Public::ProductChannel",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "product_type",
  "XTracker::Schema::Result::Public::ProductType",
  { id => "product_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "promotion_detail_product",
  "XTracker::Schema::Result::Promotion::DetailProduct",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_detail_products",
  "XTracker::Schema::Result::Promotion::DetailProducts",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pws_sort_orders",
  "XTracker::Schema::Result::Product::PWSSortOrder",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "recommended_master_products",
  "XTracker::Schema::Result::Public::RecommendedProduct",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "recommended_products",
  "XTracker::Schema::Result::Public::RecommendedProduct",
  { "foreign.recommended_product_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "season",
  "XTracker::Schema::Result::Public::Season",
  { id => "season_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->might_have(
  "shipping_attribute",
  "XTracker::Schema::Result::Public::ShippingAttribute",
  { "foreign.product_id" => "self.id" },
  { join_type => "INNER" },
);
__PACKAGE__->has_many(
  "show_measurements",
  "XTracker::Schema::Result::Public::ShowMeasurement",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_order",
  "XTracker::Schema::Result::Public::StockOrder",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_summary",
  "XTracker::Schema::Result::Product::StockSummary",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "storage_type",
  "XTracker::Schema::Result::Product::StorageType",
  { id => "storage_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "sub_type",
  "XTracker::Schema::Result::Public::SubType",
  { id => "sub_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "variants",
  "XTracker::Schema::Result::Public::Variant",
  { "foreign.product_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "world",
  "XTracker::Schema::Result::Public::World",
  { id => "world_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NMH50NDCdPSOYZ295ZCFFA

# A 'correctly' named alias for the stock_orders has_many accessor
__PACKAGE__->has_many(
    stock_orders => 'XTracker::Schema::Result::Public::StockOrder',
    { 'foreign.product_id' => 'self.id' }
);

__PACKAGE__->has_one(
    'price_default' => 'Public::PriceDefault',
    { 'foreign.product_id' => 'self.id' }
);

# On a full db dump there is only one row in the product table without a
# product_attribute entry, so we should look at either changing "attribute" to a
# has_one and keep it as an alias for product_attribute, or just keep one of
# the two and make it a has_one. - DJ
__PACKAGE__->has_one(
    'product_attribute' => 'Public::ProductAttribute',
    { 'foreign.product_id' => 'self.id' },
);

# join for the upload worker WhatsNew to use
__PACKAGE__->belongs_to(
    'product_channel_upload' => 'Public::ProductChannel',
    { 'foreign.product_id' => 'self.id' },
);

__PACKAGE__->might_have(
    'pws_sort_order' => 'Product::PWSSortOrder',
    { 'foreign.product_id' => 'self.id' },
);

__PACKAGE__->many_to_many( 'measurements', show_measurements => 'measurement' );

# These are supporting outer-join relationships to allow prefetches and joins
# over 'might_have' relationships
__PACKAGE__->belongs_to(
    'outer_designer'  => 'Public::Designer',
    { 'foreign.id' => 'self.designer_id' },
    { join_type => "LEFT OUTER" },
);
__PACKAGE__->belongs_to(
    'outer_storage_type' => 'Product::StorageType',
    { 'foreign.id' => 'self.storage_type_id' },
    { join_type => "LEFT OUTER" },
);

__PACKAGE__->many_to_many('ship_restrictions' => 'link_product__ship_restrictions', 'ship_restriction');

__PACKAGE__->load_components( qw/AuditLog/ );
__PACKAGE__->add_audit_recents_rel;
__PACKAGE__->audit_columns({
    storage_type_id => 'storage_type.name'
});

use NAP::policy;

=head1 NAME

XTracker::Schema::Result::Public::Product

=cut

use Carp;
use File::Basename;

use XTracker::Config::Local qw( config_var config_section_slurp );
use XTracker::Database qw( :common );
use XTracker::Database::Location qw( get_location_of_stock );
use XTracker::Logfile qw( xt_logger );
use XTracker::Constants::FromDB qw(
    :recommended_product_type
    :flow_status
    :product_channel_transfer_status
    :variant_type
    :country
    :sub_region
    :ship_restriction
);
use XTracker::Constants   qw( :application );
use XTracker::Image;
use XT::Rules::Solve;
use XTracker::WebContent::StockManagement::Broadcast;
use NAP::XT::Exception::Shipment::InvalidRestrictionCode;

use MooseX::Params::Validate;
use List::MoreUtils qw{any};

use Moose;
with 'XTracker::Schema::Role::Saleable',
    'XTracker::Schema::Role::Ordered',
    'XTracker::Role::WithPRLs',
    'XTracker::Role::WithAMQMessageFactory';

my $logger = xt_logger(__PACKAGE__);

sub name {
    $_[0]->product_attribute->name;
}

sub get_three_images {
    my ($self, $args) = @_;
    return XTracker::Image::get_images({
        product_id => $self->id,
        schema => $self->result_source->schema,
        ( $args ? %$args : () )
    });
}

=head2 get_large_live_image

Returns the URL to the live version of a large image for this product

=cut

sub get_large_live_image {
    my $self = shift;

    $self->get_live_image_for_size('l');
}

=head2 get_live_image_for_size( $size_string ) : $url_string

For provided string with size (could be 's', 'xs' etc) produces the URL to LIVE main image.

=cut

sub get_live_image_for_size {
    my ($self, $size) = @_;

    return shift @{$self->get_three_images({
        live => 1,
        size => $size,
    })};
}

sub has_stock {
    my $self = shift;

    my $quantities = $self->result_source->schema->resultset('Public::Quantity')
                          ->search({ quantity => {'>' => 0},
                                     'product_variant.product_id' => $self->id },
                                   {join => 'product_variant'});

    return $quantities->count;
}

sub location_info {
    my ($self) = @_;
    my $pid = $self->id();

    my $dbh = $self->result_source()->schema()->storage()->dbh();

    # XXX in an ideal world we wouldn't be using legacy DB calls ...
    my $location_info = get_location_of_stock(
        $dbh,
        {
            id              => $pid,
            type            => 'product_id',
            stock_status_id => $FLOW_STATUS__CREATIVE__STOCK_STATUS,
        }
    );

    return $location_info;
};

sub sample_location_info {
    my ($self) = @_;
    my $pid = $self->id();

    my $dbh = $self->result_source()->schema()->storage()->dbh();

    # XXX in an ideal world we wouldn't be using legacy DB calls ...
    my $location_info = get_location_of_stock(
        $dbh,
        {
            id              => $pid,
            stock_status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        }
    );

    return $location_info;
};

sub get_colour_variations {
    return shift->recommended_master_products_rs->get_colour_variations;
}

=head2 is_on_sale

An alias for is_marked_down.

=cut

sub is_on_sale { return shift->is_marked_down; }

=head2 is_marked_down

Returns a true or false value according to whether the product is marked down.

=cut

sub is_marked_down { return shift->current_markdown ? 1 : 0; }

=head2 current_markdown

Return the current markdown (related price_adjustment row) for this product.

=head3 NOTE

Shouldn't this be channelised?

=cut

sub current_markdown {
    my $self = shift;

    my $now = DateTime->now();

    for my $pa ( $self->price_adjustments->all ) {
        return $pa
            if (    DateTime->compare( $pa->date_start, $now ) < 0
                and DateTime->compare( $now, $pa->date_finish ) < 0 );
    }
    return;
}

=head2 requires_measuring() : Bool

Returns true if this product requires measuring. Note that this depends on the
DC as well.

=cut

sub requires_measuring {
    my $self = shift;
    return undef unless XT::Rules::Solve->solve('Printing::MeasurementForm');
    return !!$self->product_type
        ->product_type_measurements
        ->search(
            { channel_id => [map {$_->channel_id} $self->product_channel->all] },
            { rows => 1 }
        )->count;
}

=head1  has_classification_of

Given an array ref will check that the product is one of these classifications

(Copied from has_product_type_of below for consistencies/times sake)

=cut

sub has_classification_of {
    my($self,$classifications) = @_;
    my $schema = $self->result_source()->schema();

    my $classifications_rs = $schema->resultset('Public::Classification')->search({
        classification => { in => $classifications },
    });
    return 0 if ((!$classifications_rs) or ($classifications_rs->count == 0));

    my @classification_ids = $classifications_rs->get_column('id')->all;
    my @match = grep { $_ == $self->classification_id } @classification_ids;

    return 1 if (scalar @match > 0);
    return 0;
}

=head1 has_product_type_of

Given an array ref will check that the product is one of these product types

=cut

sub has_product_type_of {
    my($self,$product_types) = @_;
    my $schema = $self->result_source()->schema();

    my $product_types_rs = $schema->resultset('Public::ProductType')->search({
        product_type => { in => $product_types },
    });
    return 0 if ((!$product_types_rs) or ($product_types_rs->count == 0));

    my @product_type_ids = $product_types_rs->get_column('id')->all;
    my @match = grep { $_ == $self->product_type_id } @product_type_ids;

    return 1 if (scalar @match > 0);
    return 0;
}

=head2 get_product_channel
=head2 get_product_channel( $channel_id )

This sub can be called in two ways. When not passed a channel_id it gets the
product_channel that the product is currently 'active' on in accordance with
current business rules. When passed a C<$channel_id> it returns the
a product_channel DBIC::Row object on the given channel.

=cut

sub get_product_channel {
    my ($self, $channel_id) = @_;

    if ( defined $channel_id ) {
        return $self->search_related('product_channel',
            { channel_id => $channel_id },
            { rows => 1, },
        )->single;
    }

    # The thinking for the query below...
    # A product will always have a single product_channel in transfer status 'none'.
    # Usually this is the one we want, except when a product is in the middle of a channel
    # transfer. An entry for the new channel is created when the transfer is
    # requested instead of when it is completed. Until then we still want the old one.
    # So...
    # We look through all the product_channel entries that are not archived off as
    # 'Transferred' and prioritise the one that is part way through a channel transfer
    # if it exists, else we use the one with no transfer status.
    # Easy peasy! :)
    # It should be noted that the 'live' flag is not an accurate indicator of which
    # product_channel should be considered the 'currently active' entry, because it is
    # possible for a product to be channel transfered without ever having been made live
    # on the website.
    my @pc = $self->search_related('product_channel',[
        transfer_status_id => [
            $PRODUCT_CHANNEL_TRANSFER_STATUS__NONE,
            $PRODUCT_CHANNEL_TRANSFER_STATUS__REQUESTED,
            $PRODUCT_CHANNEL_TRANSFER_STATUS__IN_PROGRESS,
        ],
    ], {
        order_by => { -desc => \"CASE WHEN transfer_status_id IN (
            $PRODUCT_CHANNEL_TRANSFER_STATUS__REQUESTED,
            $PRODUCT_CHANNEL_TRANSFER_STATUS__IN_PROGRESS
        ) THEN 1 ELSE 0 END" },
    }
    )->all;
    my $pc = shift @pc;
    croak "Found no active channel for product #".$self->id
        unless $pc;

    # Return as here we have one non-live product so we don't need the
    # subsequent check
    return $pc unless $pc->is_live;

    # Sanity check for when we get more than one live product that hasn't been
    # fully transferred - effectively this means we can't work out which one
    # is active
    croak "Found more than one active channel for product #".$self->id
        if @pc && $pc[0]->is_live;
    return $pc;

}

=head2 get_current_channel_name

Returns the name of the channel that the product is currently assigned
This will return undef if no channel can be identified

=cut

sub get_current_channel_name {
    my ($self) = @_;
    my $current_channel_name;
    if(my $current_product_channel = $self->get_product_channel()) {
        if(my $current_channel = $current_product_channel->channel()) {
            $current_channel_name = $current_channel->name();
        }
    }
    return $current_channel_name;
}

=head2 get_current_channel_id

Returns the id of the channel that the product is currently assigned
This will return undef if no channel can be identified

=cut

sub get_current_channel_id {
    my ($self) = @_;
    my $current_channel_id;
    if(my $current_product_channel = $self->get_product_channel()) {
        if(my $current_channel = $current_product_channel->channel()) {
            $current_channel_id = $current_channel->id();
        }
    }
    return $current_channel_id;
}

=head2 get_product_channel_for_images

Returns a live product_channel if it can find one or a non-live one if it
can't for this product. This is useful for XTracker::Image::get_images where
we need live pictures if they exist, and get_product_channel favour non-live
ones.

Works on the assumption that live products will have better images (i.e. pws
ones, not buysheet ones) for XT than non-live ones.

=cut

sub get_product_channel_for_images {
    return $_[0]->product_channel->search(undef,
        { order_by => { -desc => 'live' },
          rows => 1, },
    )->first;
}

=head2 get_ordered_shown_measurements

Get the measurements that should be displayed for this product, ordered
according to sort_order in the product_type_measurement table.

=cut

sub get_ordered_shown_measurements {
    my ($self) = @_;

    # Join on channel using get_product_channel_for_images because that
    # returns the live channel where there is one, and we're trying
    # to return the right measurements for display on the website.
    return $self->search_related('show_measurements', {
        'product_type_measurements.product_type_id' => $self->product_type_id,
        'product_type_measurements.channel_id' => $self->get_product_channel_for_images->channel_id,
    },
    {
        'join' => {'measurement' => 'product_type_measurements'},
        'order_by' => 'product_type_measurements.sort_order',
    })->all;
}

sub wms_presentation_name {
    my ($self) = @_;

    my $designer = eval { $self->designer->designer } || 'Unknown designer';
    my $name = eval { $self->product_attribute->name } || 'Unnamed product';
    return "$designer - $name";
}

=head2 sizing_payload

Return the payload for the XT::DC::Controller::Sizing webservice and
for the "new sizes" message.

=cut
my $numerically = sub { $a <=> $b };

sub sizing_payload {
    my ($self,$channel_id) = @_;

    my $ret={};

    my $ss = $self->product_attribute->size_scheme;
    die sprintf("Product %d without size scheme", $self->id)
        unless $ss;

    $ret->{size_scheme} = $ss->name;
    $ret->{size_scheme_short_name} = $ss->short_name;

    my @variants = $self->variants->search(
        { 'size_scheme.id' => $ss->id },
        {
            prefetch => {
                size => {
                    # To get the position within the size scheme
                    'size_scheme_variant_size_size_ids' => 'size_scheme'
                }
            },
        }
    );

    my %ssvs;

    for my $variant (@variants) {
        next unless $variant->type_id == $VARIANT_TYPE__STOCK;
        my $rec = {
            variant_id => $variant->id,
            size_id => $variant->size_id,
            size => $variant->size->size,
            sku => $variant->sku,
            measurements => $variant->get_measurements_payload($channel_id),
            position => $variant
                            ->size
                            ->size_scheme_variant_size_size_ids
                            ->single({ size_scheme_id => $ss->id })
                            ->position,
        };
        if (defined $variant->designer_size_id) {
            $rec->{designer_size} = $variant->designer_size->size;
            $rec->{designer_size_id} = $variant->designer_size_id;
        }
        if (defined $variant->third_party_sku) {
            $rec->{third_party_sku} = $variant->third_party_sku->third_party_sku;
        }
        if (defined $variant->std_size_id) {
            $rec->{std_size} = {
                rank => $variant->std_size->rank,
                name => $variant->std_size->name,
            };
        }

        $ssvs{$rec->{position}} = $rec;
    }

    # It seems nice to return them in order, though we don't (at the time of
    # writing) depend on it as product collector has to sort them anyway.
    $ret->{size_scheme_variant_size} = [ @ssvs{sort $numerically keys %ssvs} ];

    return $ret;
}

=head2 get_stock_variants

Return all variants of type 'Stock'.

=cut

sub get_stock_variants {
    my ( $self ) = @_;

    my $variants = $self->search_related( 'variants',
        { 'me.type_id' => $VARIANT_TYPE__STOCK, },
        { order_by => 'me.size_id',
          prefetch => [ qw{size designer_size variant_measurements} ] },
    );
    return $variants;
}

=head2 create_variant

Creates a variant related to the current product, given the products size scheme

=cut

sub create_variant {
    my ($self, $params) = @_;

    if ( not defined $params->{legacy_sku} ) {
        croak ('Please provide a legacy_sku for the variant');
    }

    if ( not defined $params->{size_id} ) {
        croak ('Please provide a size_id for the variant');
    }
    if ( not defined $params->{designer_size_id} ) {
        croak ('Please provide a designer_size_id for the variant');
    }
    if ( not defined $params->{variant_id} ) {
        croak "Missing named argument variant_id";
    }

    $self->create_related('variants', {
        product_id       => $self->id,
        id               => $params->{variant_id},
        legacy_sku       => $self->legacy_sku,
        type_id          => 1, # Stock
        size_id          => $params->{size_id},
        designer_size_id => $params->{designer_size_id},
    } );

}

=head2 has_size_scheme_changed

Return true if size scheme id passed in, is different to the one stored in the
product_attributes table.

=cut

sub has_size_scheme_changed {
    my ($self, $size_scheme_id ) = @_;

    return ( $self->product_attribute->size_scheme_id == $size_scheme_id ) ? 0 : 1;
}

=head2 delete_related_stock_order_items

Delete all stock orders items related to this product

=cut

sub delete_related_stock_order_items {
    my ( $self ) = @_;

    my $stock_order_rs = $self->stock_order;
    while ( my $stock_order = $stock_order_rs->next ) {

        # Before deleting stock order items, we must ensure that there are
        # no deliveries "hooked" on them, and cancel deliveries if required.
        my $delivery_link_rs = $stock_order->link_delivery__stock_orders;

        while (my $delivery_link = $delivery_link_rs->next()){

            # Finding delivery through delivery link
            my $delivery = $delivery_link->delivery;

            $logger->debug("Cancelling Delivery ".$delivery->id);
            $delivery->cancel_delivery( $APPLICATION_OPERATOR_ID ); # Logging as operator "Application"

            # Going through all the delivery items / stock order items links and deleting them
            my $delivery_item_rs = $delivery->delivery_items;
            while(my $delivery_item = $delivery_item_rs->next){
                for my $stock_order_item ($stock_order->stock_order_items->all()){
                    # Finding link_delivery_item__stock_order_items for this stock order item
                    my $link_item = $delivery_item->find_related('link_delivery_item__stock_order_items',{ stock_order_item_id => $stock_order_item->id });
                    if($link_item){
                        $link_item->delete();
                    }
                }
            }
        }

        $logger->debug("Deleting all stock order items for stock order ".$stock_order->id);
        $stock_order->stock_order_items->delete();
    }
    return;
}

=head2 notify_product_service

    $product->notify_product_service;

Sends a message to Fulcrum telling Fulcrum to send this product to the
product service. Should only be needed at the point of product
creating during product generation.

=cut

sub notify_product_service {
    my ( $self ) = @_;

    my $amq = $self->msg_factory;

    # When a product is created via product generation we can't safely tell
    # the product service about the product until XT has created the product
    # (otherwise  the product service might ask XT for information about the
    # product before it's finished being fully created).
    #
    # So we tell XT to send a message to Fulcrum that then sends the basic product
    # data from Fulcrum to the product service.
    #
    # This may seem a bit long-winded but XT is not the authoritative source of
    # basic product data, so we usually send product data straight from Fulcrum,
    # however, in the case of product generation, we can't send that basic data
    # until the product is fully created in XT.
    foreach my $pc ( $self->product_channel->all ) {
        $amq->transform_and_send('XT::DC::Messaging::Producer::Product::Notify', {
            product_id => $self->id,
            channel_id => $pc->channel_id,
        });
    }
}

=head2 send_sku_update_to_prls

    $product->send_sku_update_to_prls ({'amq'=>$amq});

If PRLs are turned on, sends a message for each variant to each PRL with
the latest details.

=cut

sub send_sku_update_to_prls {
    my ($self, $args) = @_;

    foreach my $variant ($self->variants) {
        $variant->send_sku_update_to_prls($args);
    }
}

=head2 get_selling_price

Returns the price (xxx.xx) of the product.

=cut

sub get_selling_price {
    my ($self, $country) = @_;

    my $price;

    if ($self->price_country->search({country_id => $country->id})->count) {
        $price = $self->price_country->search({country_id => $country->id})->first
    }
    elsif ($self->price_region->search({region_id => $country->sub_region->region->id})->count) {
        $price = $self->price_region->search({region_id => $country->sub_region->region->id})->first;
    }
    else {
        $price = $self->price_default;
    }

    return {
        price       => $price->price,
        currency_id => $price->currency_id,
    }
}

sub get_variants_with_defined_sizes {
    my $self = shift;

    return $self->variants->search({
            type_id          => $VARIANT_TYPE__STOCK,
            designer_size_id => {'!=' => undef},
            size_id          => {'!=' => undef},
    })
}

=head2 can_ship_to_address( L<XTracker::Schema::Result::Public::OrderAddress>, L<XTracker::Schema::Result::Public::Channel> )

Return true or false if this product can be shipped to this address on this
channel.

=cut

sub can_ship_to_address {
    my ($self, $shipment_address, $channel)   = @_;

    my $country = $shipment_address->country_ignore_case;
    return $self->can_ship_to_location(
        country  => $country,
        county   => $shipment_address->county,
        postcode => $shipment_address->postcode,
        channel  => $channel,
    );
}

=head2 can_ship_to_location( %parameters )

Return TRUE or FALSE depending on whether this product can be shipped to the
given location on the given channel.

Requires the following key/value pairs:

channel - L<XTracker::Schema::Result::Public::Channel>
country - L<XTracker::Schema::Result::Public::Country>
county  - String

Example Usage:

    my $product = $schema->resultset('Public::Product')->find( $product_id );
    my $channel = $schema->resultset('Public::Channel')->find( $channel_id );
    my $country = $schema->resultset('Public::Country')->find( $country_id );

    my $boolean = $product->can_ship_to_location(
        channel => $channel,
        country => $country,
        county  => 'Some County',
    );

    print $boolean
        ? 'can ship to location'
        : 'can NOT ship to location';

=cut

sub can_ship_to_location {
    my ( $self, %parameters )   = @_;

    my $ship_attr   = $self->shipping_attribute;
    my $restrictions= XT::Rules::Solve->solve( 'Shipment::restrictions' => {
        channel_id  => $parameters{channel}->id,
        product_ref => {
            $self->id   => {
                country_of_origin   => $ship_attr->country->country,
                cites_restricted    => $ship_attr->cites_restricted,
                is_hazmat           => $ship_attr->is_hazmat,
                fish_wildlife       => $ship_attr->fish_wildlife,
                designer_id         => $self->designer_id,
                ship_restriction_ids=> $self->get_shipping_restrictions_ids_as_hash(),
            },
        },
        address_ref => {
            country_code => $parameters{country}->code,
            country      => $parameters{country}->country,
            sub_region   => $parameters{country}->sub_region->sub_region,
            county       => $parameters{county},
            postcode     => $parameters{postcode},
        },
        -schema     => $self->result_source->schema,
    } );

    # REL-10767:
    # DUE to not knowing from the business exactly what is required for DC2 for CANDO-1309
    # in relation to 'Python' products, will have to TEMPORARILY include 'notify' as a restriction
    # in order to make sure things work as they have been doing and don't allow Pre-Orders
    # to be created with products for destinations they can't be shipped to and thus ending
    # up cancelling the eventual Orders and annoying our EIPs.
    return 0        if ( $restrictions && ( $restrictions->{restrict} || $restrictions->{notify} ) );
    return 1;
}

=head2 can_be_pre_ordered_in_channel

Returns true or false if this product is available for pre order on the specific channel

=cut

sub can_be_pre_ordered_in_channel {
    my ($self, $channel_id) = @_;

    if ($self->get_product_channel($channel_id)->is_live()) {
        $logger->debug('Product live in channel');
        return 0;
    }
    else {
        $logger->debug('Product not live in channel');
        return 1;
    }
}

=head2 preorder_name

What this product is called for pre-order purposes.

If the product has a name, use that, with the designer name prepended
if available.

Otherwise, fall back to the buy sheet notes, which amusingly end up in
XT's description attribute, for some reason.

=cut

sub preorder_name {
    my $self = shift;

    if ( $self->name ) {
        if ( $self->designer_id ) {
            # use the same rule for combining designer and name as
            # already written earlier
            return $self->wms_presentation_name;
        }
        else {
            return $self->name;
        }
    }

    # this is really the Buy Sheet notes, but it's usually the first
    # thing that is completed on a new product, even when all the other
    # fields are missing
    return $self->product_attribute->description;
}

=head2 get_variants_for_pre_order

    $array_ref  = $product->get_variants_for_pre_order( $channel, {
                                                        # optional argument to exclude a variant from the list
                                                        exclude_variant_id => $variant_id,
                                                    } );

This will return an Array Ref of Hash Ref's containing all of the Variants for a product with an indicator of whether they have enough stock to
be Pre-Ordered. An optional 'exclude_variant_id' argument can be passed in so that the list can exclude a Variant such as the one the Customer
has already ordered.

The list returned:
    [
        {
            variant     => variant DBIC object,
            is_available=> TRUE or FALSE,
        },
    ],

=cut

sub get_variants_for_pre_order {
    my ( $self, $channel, $args )    = @_;

    if ( !$channel || !ref( $channel ) ) {
        croak "No Channel Object passed in to '" . __PACKAGE__ . "->get_variants_for_pre_order'";
    }

    my $exclude_variant_id  = $args->{exclude_variant_id} || 0;

    my @retval;
    my @variants    = $self->variants->by_size_id->all;

    VARIANT:
    foreach my $variant ( @variants ) {
        next VARIANT        if ( $exclude_variant_id == $variant->id );

        push @retval, {
                variant     => $variant,
                is_available=> $variant->can_be_pre_ordered_in_channel( $channel->id ),
            };
    }

    return \@retval;
}

sub is_voucher { return 0; }

=head2 broadcast_stock_levels( full_details => bool )

Broadcasts a stock level update. Defaults to 'not full details', but this
can be overridden by passing a true value as a parameter named full_details

=cut

sub broadcast_stock_levels {
    my ( $self, %args ) = @_;

    $args{full_details} //= 0;

    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $self->result_source->schema,
        channel_id => $self->get_product_channel->channel_id,
    });
    $broadcast->stock_update(
        quantity_change => 0,
        product_id => $self->id,
        full_details => $args{full_details},
    );
    $broadcast->commit();

    return;
}

=head2 broadcast_sizing

Broadcast sizing for the product (implies broadcast stock details)

This needs to be done if the size scheme/variants are updated.

=cut

sub broadcast_sizing {
    my ( $self ) = @_;

    $self->msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::ProductService::Sizing',
        {
            product     => $self,
            channel_id  => $self->get_product_channel->channel_id,
            size_scheme => $self->product_attribute->size_scheme->name,
        },
    );

    # Notify product service of stock level detail update
    $self->broadcast_stock_levels( full_details => 1 );

    return;
}

=head2 add_shipping_restrictions

Add a list of shipping restrictions to this product

param - $restriction_codes : A list of shipping restriction codes

=cut

sub add_shipping_restrictions {
    my ($self, $restriction_codes) = validated_list(\@_,
        restriction_codes => { isa => 'ArrayRef[Str]' },
    );

    my ($ship_restriction_rs, $ship_restrictions)
        = $self->_check_for_bad_restriction_codes($restriction_codes);


    $self->result_source->schema->txn_do(sub {
        $self->update_or_create_related('link_product__ship_restrictions', {
            ship_restriction_id => $_->id(),
        }) for @$ship_restrictions;
    });

    return 1;
}

=head2 remove_shipping_restrictions

Remove a list of shipping restrictions from this product

param - $restriction_codes : A list of shipping restriction codes

=cut

sub remove_shipping_restrictions {
    my ($self, $restriction_codes) = validated_list(\@_,
        restriction_codes => { isa => 'ArrayRef[Str]' },
    );

    my ($ship_restriction_rs, $ship_restrictions)
        = $self->_check_for_bad_restriction_codes($restriction_codes);

    $self->search_related('link_product__ship_restrictions', {
        ship_restriction_id => { -in => $ship_restriction_rs->get_column('id')->as_query() }
    })->delete();

    return 1;
}

=head2 get_shipping_restrictions_codes

Will return arrayref of shipping restriction codes

=cut
sub get_shipping_restrictions_codes {
    my ($self) = @_;

    my @shipping_restrictions = $self->ship_restrictions();

    my @codes = map { $_->code() } @shipping_restrictions;
    return \@codes;
}

sub _check_for_bad_restriction_codes {
    my ($self, $submited_codes) = @_;

    my $ship_restriction_rs = $self->result_source->schema
        ->resultset('Public::ShipRestriction')->search({
        code => $submited_codes,
    });

    my @ship_restrictions = $ship_restriction_rs->all();

    if (scalar(@ship_restrictions) != @$submited_codes) {
        # At least one ship restriction could not be found

        my $missing_codes = [];
        for my $code_requested (@$submited_codes) {
            next if grep { $code_requested eq $_->code() } @ship_restrictions;
            push @$missing_codes, $code_requested;
        }
        NAP::XT::Exception::Shipment::InvalidRestrictionCode->throw({
            unknown_codes => $missing_codes,
        });
    }

    return ($ship_restriction_rs, \@ship_restrictions);
}

=head2 get_channel

Return the channel this product is currently assigned to

=cut

sub get_channel {
    my ($self) = @_;
    return $self->get_product_channel()->channel();
}

=head2 get_shipping_restrictions_ids

Will return arrayref of shipping restriction ids

=cut
sub get_shipping_restrictions_ids {
    my ($self) = @_;

    my @shipping_restrictions = $self->ship_restrictions();

    my @ids = map { $_->id() } @shipping_restrictions;
    return \@ids;
}

=head2 get_shipping_restrictions_ids_as_hash

    $hash_ref = $self->get_shipping_restrictions_ids_as_hash();

Returns a Hash Ref. where the Shipping Id is the key and all Values
are '1'. This is to allow an exist check can be done with one of
the Ship Restriction Constants to make it easier to determin if
a Product has a particualr Restriction.

=cut

sub get_shipping_restrictions_ids_as_hash {
    my $self = shift;

    my $ids = $self->get_shipping_restrictions_ids();

    return {
        map { $_ => 1 }
            @{ $ids }
    };
}

=head2 get_shipping_restrictions_status() : \%restrictions

Will return hashref of shipping restrictions status

=cut
sub get_shipping_restrictions_status {
    my ($self) = @_;

    my $restriction_ids = $self->get_shipping_restrictions_ids;

    my $restrictions = {};
    $restrictions->{is_hazmat}        = 1
        if any { $SHIP_RESTRICTION__HAZMAT    == $_ } @$restriction_ids;
    $restrictions->{is_aerosol}       = 1
        if any { $SHIP_RESTRICTION__HZMT_AERO == $_ } @$restriction_ids;
    $restrictions->{is_fish_wildlife} = 1
        if any { $SHIP_RESTRICTION__FISH_WILD == $_ } @$restriction_ids;
    $restrictions->{is_hazmat_lq}     = 1
        if any { $SHIP_RESTRICTION__HZMT_LQ   == $_ } @$restriction_ids;

    return $restrictions;
}


=head2 get_client

Return the client associated with this product

=cut

sub get_client {
    my ($self) = @_;
    return $self->get_channel()->client();
}

=head2 has_ship_restriction($restriction_code) : Bool

Returns a true value if this product has the given C<$restriction_code>.

=cut

sub has_ship_restriction {
    my ( $self, $code ) = @_;
    return !!$self->ship_restrictions->find({ code => $code });
}

=head2 small_labels_per_item() : $labels_per_item

Returns the number of small labels to be printed for this class of items.

=cut

sub small_labels_per_item {
    my $self = shift;
    my $small_product_type = $self->product_type->small_labels_per_item_override;
    my $small_classification = $self->classification->small_labels_per_item_override;

    # Ensure data consistency:
    die "Can't define number of small labels for both Product Type and Classification"
        if defined $small_product_type && defined $small_classification;

    return $small_product_type // $small_classification // 1;
}

=head2 large_labels_per_item() : $labels_per_item

Returns the number of large labels to be printed for this class of items.

=cut

sub large_labels_per_item {
    my $self = shift;
    my $large_product_type = $self->product_type->large_labels_per_item_override;
    my $large_classification = $self->classification->large_labels_per_item_override;

    # Ensure data consistency:
    die "Can't define number of large labels for both Product Type and Classification"
        if defined $large_product_type && defined $large_classification;

    return $large_product_type // $large_classification // 1;
}

=head2 hide_measurement( $measurement_id ) :

Delete the corresponding row from show_measurement table for this product.

=cut

sub hide_measurement {
    my ( $self, $measurement_id ) = @_;

    return $self->delete_related(
        'show_measurements', { measurement_id => $measurement_id }
    );
}

=head2 show_measurement( $measurement_id )

Add the corresponding row to the show_measurement table.

=cut

sub show_measurement {
    my ( $self, $measurement_id ) = @_;

    return $self->find_or_create_related(
        'show_measurements',
        { product_id => $self->id, measurement_id => $measurement_id },
        { key => 'show_measurement_product_id_measurement_id' }
    );
}

=head2 show_default_measurements

Add entries to the show_measurement table for all measurements of this
product's product type.

=cut

sub show_default_measurements {
    my $self = shift;

    my @measurements = $self->product_type->measurements_for_channels(
        map { $_->channel_id } $self->product_channel->all
    );

    $self->show_measurement($_->measurement_id) for @measurements;
}

=head2 add_volumetrics(:length, :width, :height) :

An alias for L<XTracker::Schema::Result::Public::ShippingAttribute::add_volumetrics>.

=cut

sub add_volumetrics { shift->shipping_attribute->add_volumetrics(@_); }


=head2 get_ship_restriction_by_id

    For given <ID> it queries L<Public::ShipRestriction> table and fetches record.

=cut

sub get_ship_restriction_by_id {
    my ( $self, $restriction_id ) = @_;

    my $restriction =  $self->ship_restrictions->find($restriction_id);

    return $restriction;
}

=head2 is_excluded_from_location

   Boolean  = $product->is_excluded_from_location ({
                ship_restriction_id => <id>,
                country => 'United Kingdom',
                postcode => 'UB3 5AH'
              });
  This method checks shipping restriction tables for given product by checking
  if it is an allowed country and it is not excluded postcode, it returns True else False.

=cut

sub is_excluded_from_location {
    my $self        = shift;
    my $parameters  = shift;


    my $ship_restriction_id = $parameters->{ship_restriction_id};
    my $country             = $parameters->{country};
    my $postcode            = $parameters->{postcode};
    my $restriction;
    my $country_obj;
    my $country_id;
    my $allowed_country;


    if( $ship_restriction_id ) {
        $restriction  = $self->get_ship_restriction_by_id($ship_restriction_id);
        # return FALSE if there is no restriction is
        return 0 unless $restriction;
    } else {
        croak "No ship_restriction_id passed in to '" . __PACKAGE__ . "->is_excluded_from_location'";
    }


    my $schema = $self->result_source()->schema();
    # Check for Country
    if( $country && $restriction ) {
       $country_obj =  $schema->resultset('Public::Country')->search({ country => $country })->first;
       if( $country_obj) {
            $country_id= $country_obj->id;
            $allowed_country = $restriction->ship_restriction_allowed_countries->search(
            {
                country_id => $country_id,

            })->first;
            return 1 unless $allowed_country;
       }
       else {
            croak "Can't find country passed in to '" . __PACKAGE__ . "->is_excluded_from_location'";
       }
    }

    # Check for postcode
    my $ship_exclude_postcode =  $restriction->search_related('ship_restriction_exclude_postcodes', {
        country_id => $country_id
    });
    my @exclude_postcodes = map {$_->postcode} $ship_exclude_postcode->all;

    # if NO postcodes to check for this country, then not excluded
    return 0        if ( !@exclude_postcodes );

    $postcode //= '';
    $postcode = uc($postcode);
    $postcode =~ s/\s//g;

    if ( $postcode eq '' ) {
        # need a postcode, so must die
        croak "No Postcode for Country with Excluded Postcodes passed in to '" . __PACKAGE__ . "->is_excluded_from_location'";
    }

    return XT::Rules::Solve->solve( 'Address::is_postcode_in_list_for_country' => {
        country_id    => $country_id,
        postcode      => $postcode,
        postcode_list => \@exclude_postcodes,
    } );
}

1;
